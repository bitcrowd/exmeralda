defmodule Exmeralda.Regenerations do
  @moduledoc """
  Context around regenerating messages
  """
  require Logger

  import Ecto.Query
  alias Exmeralda.Repo
  alias Exmeralda.Chats
  alias Exmeralda.Regenerations.Server, as: RegenerationServer
  alias Exmeralda.Regenerations.JSON, as: JSONFormatter
  alias Ecto.Multi
  alias Exmeralda.Chats.{Message, Session, GenerationEnvironment}

  @type regenerate_opts :: [download: boolean(), download_path: String.t()]
  @spec regenerate_messages([Message.id()], GenerationEnvironment.id()) :: map()
  @spec regenerate_messages([Message.id()], GenerationEnvironment.id(), regenerate_opts()) ::
          map()
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

        result = %{
          regenerated_messages:
            Enum.map(state.regenerated_messages, fn {k, v} ->
              {k, Map.take(v, [:assistant_message_id])}
            end),
          skipped_messages: state.skipped_messages
        }

        if download? do
          Logger.info("🎁 Results: #{inspect(result)}")

          download(
            Enum.map(state.regenerated_messages, fn {_k, v} -> v.assistant_message_id end),
            opts
          )
        else
          Logger.info("🎁 Results:")
          result
        end
    end
  end

  @default_download_path "./regenerations"
  @type download_opts :: [download_path: String.t()]
  @spec download([Message.id()]) :: {:ok, String.t()}
  @spec download([Message.id()], download_opts()) :: {:ok, String.t()}
  def download(assistant_message_ids, opts \\ []) do
    download_path = Keyword.get(opts, :download_path, @default_download_path)

    if !File.exists?(download_path), do: File.mkdir!(download_path)
    path = "#{download_path}/regeneration_#{DateTime.to_iso8601(DateTime.utc_now(), :basic)}.json"
    File.write!(path, Jason.encode!(JSONFormatter.format_regeneration(assistant_message_ids)))

    Logger.info("✅ Download finished! Check the file: #{path}")
    {:ok, path}
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
      copied_until_message_id: message_id,
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
      message
      |> Map.take([:index, :role, :content, :incomplete, :generation_environment_id])
      |> set_new_generation_environment_on_last_user_message(index, generation_environment_id)
      |> Map.put(:sources, Enum.map(message.sources, &Map.take(&1, [:chunk_id])))
    end)
  end

  defp set_new_generation_environment_on_last_user_message(
         params,
         index,
         generation_environment_id
       ) do
    # Old messages keep their original generation environment, as we are not regenerating them.
    # However the user message for which we are regenerating an answer *should* get the requested
    # generation_environment_id, as this attribute is used when generating the assistant answer.
    if params.index == index - 1 do
      Map.put(params, :generation_environment_id, generation_environment_id)
    else
      params
    end
  end

  defp get_user_message(_, %{original_message: %{index: index}, session: session}) do
    {:ok, Enum.find(session.messages, &(&1.index == index - 1))}
  end
end
