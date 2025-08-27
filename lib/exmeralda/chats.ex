defmodule Exmeralda.Chats do
  @moduledoc """
  The Chats context.
  """

  import Ecto.Query, warn: false
  alias Exmeralda.Repo
  alias Ecto.Multi
  alias Phoenix.PubSub

  alias Exmeralda.Topics.{Rag, Chunk, Ingestion, Library}
  alias Exmeralda.Chats.{LLM, Message, Reaction, Session, Source, GenerationEnvironment}
  alias Exmeralda.LLM.{ModelConfigProvider, SystemPrompt}
  alias Exmeralda.Accounts.User

  @message_preload [:source_chunks, :reaction]

  @doc """
  Returns the list of chat_sessions of a user.
  """
  def list_sessions(user) do
    user.id
    |> session_scope()
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single session of a user.
  """
  def get_session!(user_id, id) do
    user_id
    |> session_scope()
    |> Repo.get!(id)
    |> Repo.preload(messages: [@message_preload])
  end

  defp session_scope(user_id) do
    from s in Session, where: s.user_id == ^user_id, preload: :library
  end

  @spec list_sessions_for_ingestion(Ingestion.id()) :: [Session.t()]
  def list_sessions_for_ingestion(ingestion_id) do
    from(s in Session, where: s.ingestion_id == ^ingestion_id)
    |> Repo.all()
  end

  @spec list_sessions_for_library(Library.id()) :: [Session.t()]
  def list_sessions_for_library(library_id) do
    from(s in Session, join: i in assoc(s, :ingestion), where: i.library_id == ^library_id)
    |> Repo.all()
  end

  @doc """
  Gets a single message.
  """
  def get_message!(id) do
    Repo.get!(Message, id) |> Repo.preload(@message_preload)
  end

  @doc """
  Starts a session.
  """
  @type start_session_attrs :: %{
          ingestion_id: Ingestion.id(),
          library_id: Library.id(),
          prompt: String.t()
        }

  @spec start_session(User.t(), start_session_attrs()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def start_session(user, attrs) do
    Multi.new()
    |> Multi.run(:library_lock, fn _, _ ->
      {:ok, Repo.advisory_xact_lock("library:#{Map.fetch!(attrs, "library_id")}")}
    end)
    |> Multi.insert(:session, Session.create_changeset(%Session{user_id: user.id}, attrs))
    |> upsert_generation_environment()
    |> Multi.insert(:message, fn %{
                                   session: session,
                                   generation_environment: generation_environment
                                 } ->
      %Message{
        role: :user,
        content: session.prompt,
        index: 0,
        session_id: session.id,
        generation_environment_id: generation_environment.id
      }
    end)
    |> Multi.put(:previous_messages, [])
    |> assistant_message()
    |> Repo.transaction()
    |> case do
      {:ok, %{session: session, message: message, assistant_message: assistant_message}} ->
        {:ok, Map.put(session, :messages, [message, Map.put(assistant_message, :sources, [])])}

      {:error, :session, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Continues a session.
  """
  @type continue_session_attrs :: %{
          index: integer(),
          content: String.t()
        }

  @spec continue_session(Session.t(), continue_session_attrs()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def continue_session(session, params) do
    Multi.new()
    |> Multi.put(:session, session)
    |> Multi.put(:previous_messages, all_messages(session))
    |> upsert_generation_environment()
    |> Multi.insert(:message, fn %{
                                   session: session,
                                   generation_environment: generation_environment
                                 } ->
      %Message{
        role: :user,
        session_id: session.id,
        generation_environment_id: generation_environment.id
      }
      |> Message.changeset(params)
    end)
    |> assistant_message()
    |> Repo.transaction()
    |> case do
      {:ok, %{message: message, assistant_message: assistant_message}} ->
        {:ok, [message, Map.put(assistant_message, :sources, [])]}

      {:error, :message, changeset, _} ->
        {:error, changeset}
    end
  end

  defp all_messages(%Session{id: session_id}) do
    from(m in Message,
      where: m.session_id == ^session_id,
      order_by: [asc: :index]
    )
    |> Repo.all()
  end

  defp upsert_generation_environment(multi) do
    generation_environment_params = current_llm_config()

    multi
    |> Multi.insert(
      :generation_environment,
      fn _ -> Map.merge(%GenerationEnvironment{}, generation_environment_params) end,
      returning: [:id],
      conflict_target: [:model_config_provider_id, :system_prompt_id],
      # See https://hexdocs.pm/ecto/constraints-and-upserts.html#upserts
      # We are setting to force an update and return the same ID as the existing record.
      on_conflict: [
        set: [model_config_provider_id: generation_environment_params.model_config_provider_id]
      ]
    )
  end

  defp assistant_message(multi) do
    multi
    |> Multi.insert(:assistant_message, fn %{session: session, message: message} ->
      %Message{
        role: :assistant,
        content: "",
        session_id: session.id,
        generation_environment_id: message.generation_environment_id,
        index: message.index + 1,
        incomplete: true
      }
    end)
    |> Multi.run(:request_generation, &request_generation/2)
  end

  defp request_generation(_, %{
         previous_messages: previous_messages,
         message: message,
         assistant_message: assistant_message,
         session: session
       }) do
    session = Repo.preload(session, [:ingestion])

    handler = %{
      on_llm_new_delta: fn _model, %LangChain.MessageDelta{} = data ->
        send_session_update(session, {:message_delta, assistant_message.id, data.content})
      end,
      on_message_processed: fn _chain, %LangChain.Message{} = data ->
        assistant_message =
          Repo.update!(
            assistant_message
            |> Message.changeset(%{incomplete: false, content: data.content})
          )
          |> Repo.preload(@message_preload)

        send_session_update(session, {:message_completed, assistant_message})
      end
    }

    Task.Supervisor.start_child(Exmeralda.TaskSupervisor, fn ->
      {chunks, generation} = build_generation(message, session.ingestion.id)
      insert_sources(session, chunks, assistant_message)

      case LLM.stream_responses(
             previous_messages ++ [%{message | content: generation.prompt}],
             message.generation_environment_id,
             handler
           ) do
        {:ok, responses} ->
          {:ok, responses}

        {:error, _chain, error} ->
          raise "Error when building generation #{inspect(error)} - check the server logs!"
      end
    end)
  end

  defp build_generation(message, ingestion_id) do
    scope = from c in Chunk, where: c.ingestion_id == ^ingestion_id

    Rag.build_generation(scope, message.content, ref: message)
  end

  defp insert_sources(session, chunks, assistant_message) do
    Repo.insert_all(
      Source,
      Enum.map(chunks, &%{chunk_id: &1.id, message_id: assistant_message.id})
    )

    send_session_update(session, {:sources, assistant_message.id})
  end

  defp send_session_update(session, payload) do
    PubSub.broadcast(
      Exmeralda.PubSub,
      "user-#{session.user_id}",
      {:session_update, session.id, payload}
    )
  end

  @doc """
  Deletes a session.
  """
  @spec unlink_user_from_session(User.id(), Session.id()) ::
          {:ok, Session.t()} | {:error, {:not_found, Session}}
  def unlink_user_from_session(user_id, session_id) do
    with {:ok, session} <- Repo.fetch_by(Session, id: session_id, user_id: user_id) do
      session
      |> Session.unset_user_changeset()
      |> Repo.update()
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session changes.
  """
  def new_session_changeset(attrs \\ %{}) do
    Session.create_changeset(%Session{}, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for a new message.
  """
  def new_message_changeset(attrs \\ %{}) do
    Message.changeset(%Message{role: :user}, attrs)
  end

  @doc """
  Upserts a reaction for a message.
  """
  @spec upsert_reaction(Message.id(), atom()) ::
          {:ok, Message.t()}
          | {:error, :message_not_from_assistant}
          | {:error, {:not_found, Message}}
  def upsert_reaction(message_id, type) do
    Repo.transact(fn ->
      with {:ok, message} <- Repo.fetch(Message, message_id, lock: :no_key_update),
           :ok <- message_from_assitant?(message),
           {:ok, _} <- do_upsert_reaction(message_id, type) do
        {:ok, Repo.preload(message, @message_preload)}
      end
    end)
  end

  defp message_from_assitant?(%{role: :assistant}), do: :ok
  defp message_from_assitant?(_), do: {:error, :message_not_from_assistant}

  defp do_upsert_reaction(message_id, type) do
    Repo.insert(
      %Reaction{
        message_id: message_id,
        type: type
      },
      on_conflict: {:replace, [:type]},
      conflict_target: [:message_id]
    )
  end

  @doc """
  Deletes a reaction.
  """
  @spec delete_reaction(Reaction.id()) :: :ok
  def delete_reaction(reaction_id) do
    case Repo.fetch(Reaction, reaction_id) do
      {:ok, reaction} ->
        Repo.delete(reaction, allow_stale: true)
        :ok

      _ ->
        :ok
    end
  end

  @spec count_reactions_for_ingestions([Ingestion.id()]) :: map()
  def count_reactions_for_ingestions(ingestion_ids) do
    from(r in Reaction,
      left_join: m in assoc(r, :message),
      left_join: s in assoc(m, :session),
      where: s.ingestion_id in ^ingestion_ids,
      group_by: [s.ingestion_id, r.type],
      select: %{ingestion_id: s.ingestion_id, count: {r.type, count(r.id)}}
    )
    |> Repo.all()
    |> Enum.group_by(& &1.ingestion_id, & &1.count)
  end

  defp current_llm_config do
    %{model_config_provider_id: model_config_provider_id, system_prompt_id: system_prompt_id} =
      Application.fetch_env!(:exmeralda, :llm_config)

    Repo.get(ModelConfigProvider, model_config_provider_id) ||
      raise "Could not find the current LLM model config provider!"

    Repo.get(SystemPrompt, system_prompt_id) ||
      raise "Could not find the current LLM system prompt!"

    %{model_config_provider_id: model_config_provider_id, system_prompt_id: system_prompt_id}
  end
end
