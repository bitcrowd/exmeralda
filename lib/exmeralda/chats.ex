defmodule Exmeralda.Chats do
  @moduledoc """
  The Chats context.
  """

  import Ecto.Query, warn: false
  alias Exmeralda.Repo
  alias Ecto.Multi
  alias Phoenix.PubSub

  alias Exmeralda.Topics.{Rag, Chunk, Ingestion}
  alias Exmeralda.Chats.{LLM, Message, Reaction, Session, Source}
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
  def get_session!(user, id) do
    user.id
    |> session_scope()
    |> Repo.get!(id)
    |> Repo.preload(messages: [@message_preload])
  end

  defp session_scope(user_id) do
    from s in Session, where: s.user_id == ^user_id, preload: :library
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
          prompt: String.t()
        }

  @spec start_session(User.t(), start_session_attrs()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def start_session(user, attrs) do
    Multi.new()
    |> Multi.insert(:session, Session.create_changeset(%Session{user_id: user.id}, attrs))
    |> Multi.insert(:message, fn %{session: session} ->
      %Message{role: :user, content: session.prompt, index: 0, session: session}
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
    |> Multi.insert(:message, fn %{session: session} ->
      %Message{role: :user, session_id: session.id} |> Message.changeset(params)
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

  defp assistant_message(multi) do
    multi
    |> Multi.insert(:assistant_message, fn %{session: session, message: message} ->
      %Message{
        role: :assistant,
        content: "",
        session_id: session.id,
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

      LLM.stream_responses(
        previous_messages ++ [%{message | content: generation.prompt}],
        handler
      )
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
  @spec delete_session(Session.t()) :: {:ok, Session.t()}
  def delete_session(%Session{} = session) do
    Repo.delete(session)
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
  Gets the reaction for message and user.
  """
  def get_reaction(message_id, user_id) do
    Repo.get_by(Reaction, message_id: message_id, user_id: user_id)
  end

  @doc """
  Creates a reaction for a message and user.
  """
  def create_reaction(message_id, user_id, type) do
    Reaction.changeset(%{message_id: message_id, user_id: user_id, type: type})
    |> Repo.insert()
  end

  @doc """
  Toggles a reaction for a message and user:
  - if there is no current reaction, a new reaction will be created.
  - if the current reaction is of `type`, it will be deleted.
  - if the current reaction is not of `type`, it will be deleted and a new reaction of `type` will be created.
  """
  def toggle_reaction(message_id, user_id, type) do
    case get_reaction(message_id, user_id) do
      nil ->
        create_reaction(message_id, user_id, type)

      %{type: ^type} = reaction ->
        Repo.delete(reaction)

      reaction ->
        with {:ok, _reaction} <- Repo.delete(reaction) do
          create_reaction(message_id, user_id, type)
        end
    end
  end
end
