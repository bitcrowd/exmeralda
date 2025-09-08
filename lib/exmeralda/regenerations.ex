defmodule Exmeralda.Regenerations do
  @moduledoc """
  Context around regenerating messages
  """
  require Logger

  import Ecto.Query, warn: false
  alias Exmeralda.Repo
  alias Exmeralda.Chats
  alias Exmeralda.Regenerations.Server, as: RegenerationServer
  alias Ecto.Multi
  alias Exmeralda.Chats.{Message, Session, GenerationEnvironment}

  @path "./regenerations"
  @spec regenerate_messages([Message.id()], GenerationEnvironment.id()) :: map()
  def regenerate_messages(message_ids, generation_environment_id, opts \\ []) do
    if Mix.env() == :prod do
      raise "sorry this only works locally for now"
    end

    download? = Keyword.get(opts, :download, false)

    Logger.info("🏁 Initiating the regeneration. This can take some time...")
    Process.flag(:trap_exit, true)

    {:ok, pid} =
      GenServer.start(RegenerationServer, %{
        message_ids: message_ids,
        generation_environment_id: generation_environment_id
      })

    ref = Process.monitor(pid)
    state = GenServer.call(pid, :regenerate)

    if state.regenerated_messages == %{} do
      GenServer.stop(pid, {:shutdown, :nothing_to_regenerate})
      Logger.info("💥 Nothing to regenerate! Reason:")
    end

    receive do
      {:DOWN, ^ref, :process, ^pid, {:shutdown, :nothing_to_regenerate}} ->
        Logger.info("Skipped Messages:")
        state.skipped_messages

      {:DOWN, ^ref, :process, ^pid, :normal} ->
        Logger.info("✅ Regeneration finished")
        Logger.info("Skipped Messages:")
        state.skipped_messages
        Logger.info("Regenerated Messages:")

        if download? do
          download(
            Enum.map(state.regenerated_messages, fn {_k, v} -> v.assistant_message_id end),
            opts
          )
        else
          %{
            regenerated_messages:
              Enum.map(state.regenerated_messages, fn {k, v} ->
                {k, Map.take(v, [:assistant_message_id])}
              end),
            skipped_messages: state.skipped_messages
          }
        end
    end
  end

  def download(assistant_message_ids, opts) do
    download_path = Keyword.get(opts, :download_path, @path)

    if !File.exists?(download_path), do: File.mkdir!(download_path)
    path = "#{download_path}/regeneration_#{DateTime.to_iso8601(DateTime.utc_now(), :basic)}.json"
    File.write!(path, Jason.encode!(format_regeneration(assistant_message_ids)))

    Logger.info("✅ Download finished! Check the file: #{path}")
    {:ok, path}
  end

  defp format_regeneration(assistant_message_ids) do
    from(m in Message,
      where: m.id in ^assistant_message_ids and not is_nil(m.regenerated_from_message_id),
      preload: [
        generation_environment: [
          :system_prompt,
          :generation_prompt,
          model_config_provider: [:model_config, :provider]
        ]
      ]
    )
    |> Repo.all()
    |> Enum.map(fn assistant_message ->
      user_message =
        Repo.one(
          from(m in Message,
            where:
              m.session_id == ^assistant_message.session_id and
                m.index == ^assistant_message.index - 1
          )
        )

      %{
        generation_environment:
          format_generation_environment(assistant_message.generation_environment),
        generation: %{
          user_query: user_message.content,
          user_message_id: user_message.id,
          chunks: format_chunks(assistant_message),
          full_user_prompt: "TODO",
          assistant_response: assistant_message.content,
          assistant_message_id: assistant_message.id
        }
      }
    end)
  end

  defp format_generation_environment(
         %{model_config_provider: %{model_config: model_config, provider: provider}} =
           generation_environment
       ) do
    embedding = Application.fetch_env!(:exmeralda, :embedding_config)

    %{
      model_name: model_config.name,
      model_provider: provider.type,
      model_provider_config:
        %{
          model: generation_environment.model_config_provider.name
        }
        |> Map.merge(model_config.config)
        |> Map.merge(provider.config),
      system_prompt: generation_environment.system_prompt.prompt,
      prompt_template: generation_environment.generation_prompt.prompt,
      embedding_model: embedding.model,
      embedding_provider: embedding.provider,
      embedding_provider_config: embedding.config,
      id: generation_environment.id
    }
  end

  defp format_chunks(assitant_message) do
    %{source_chunks: chunks} = Repo.preload(assitant_message, [:source_chunks])

    chunks
    |> Enum.map(&Map.take(&1, [:id, :source, :content]))
  end

  @spec regenerate(Message.id(), GenerationEnvironment.id()) ::
          {:ok,
           %{
             session_id: Session.id(),
             user_message: Message.t(),
             assistant_message: Message.t(),
             generation_environment: GenerationEnvironment.t()
           }}
          | {:error, {:not_found, Message}}
          | {:error, {:message_not_from_user, String.t()}}
          | {:error, {:not_found, GenerationEnvironment}}
          | {:error, Ecto.Changeset.t()}
  def regenerate(message_id, generation_environment_id) do
    Multi.new()
    |> Multi.put(:message_id, message_id)
    |> Multi.put(:generation_environment_id, generation_environment_id)
    |> Multi.run(:original_message, &fetch_message_for_regeneration/2)
    |> Multi.run(:generation_environment, &fetch_generation_environment/2)
    |> Multi.insert(:session, &duplicate_session/1)
    |> Multi.run(:message, &get_user_message/2)
    |> Chats.assistant_message(%{regenerated_from_message_id: message_id})
    |> Repo.transaction()
    |> case do
      {:ok,
       %{
         session: session,
         assistant_message: assistant_message,
         message: message,
         generation_environment: generation_environment
       }} ->
        {:ok,
         %{
           session_id: session.id,
           user_message: message,
           assistant_message: assistant_message,
           generation_environment: generation_environment
         }}

      {:error, _, error, _} ->
        {:error, error}
    end
  end

  defp fetch_message_for_regeneration(_repo, %{message_id: message_id}) do
    case Repo.fetch(Message, message_id, preload: [:session]) do
      {:ok, %{role: :user}} ->
        {:error, {:message_not_from_assistant, "message #{inspect(message_id)} has role: :user"}}

      {:ok, message} ->
        {:ok, message}

      {:error, {:not_found, Message}} ->
        {:error, {:not_found, Message}}
    end
  end

  defp fetch_generation_environment(_repo, %{generation_environment_id: generation_environment_id}) do
    Repo.fetch(GenerationEnvironment, generation_environment_id,
      preload: [
        :system_prompt,
        :generation_prompt,
        model_config_provider: [:model_config, :provider]
      ]
    )
  end

  defp duplicate_session(%{
         original_message: %{id: message_id, session: session} = original_message,
         generation_environment_id: generation_environment_id
       }) do
    session
    |> Map.take([:title, :ingestion_id])
    |> Map.merge(%{
      original_session_id: session.id,
      # TODO: MAybe not necessary...
      copied_from_message_id: message_id,
      messages: get_previous_messages(original_message, generation_environment_id)
    })
    |> Session.duplicate_changeset()
  end

  defp get_previous_messages(%{index: index, session_id: session_id}, generation_environment_id) do
    from(m in Message,
      where: m.session_id == ^session_id and m.index < ^index,
      preload: [:sources]
    )
    |> Repo.all()
    |> Enum.map(fn message ->
      params =
        Map.take(message, [:index, :role, :content, :incomplete, :generation_environment_id])

      params =
        if params.index == index - 1 do
          Map.put(params, :generation_environment_id, generation_environment_id)
        else
          params
        end

      Map.put(params, :sources, Enum.map(message.sources, &Map.take(&1, [:chunk_id])))
    end)
  end

  defp get_user_message(_, %{original_message: %{index: index}, session: session}) do
    {:ok, Enum.find(session.messages, &(&1.index == index - 1))}
  end
end
