defmodule Exmeralda.Topics.PollIngestionEmbeddingsWorker do
  use Oban.Worker,
    queue: :poll_ingestion,
    unique: [
      period: {2, :minutes},
      fields: [:args],
      states: [:available, :scheduled, :executing, :retryable]
    ]

  alias Exmeralda.Repo
  alias Exmeralda.Topics
  alias Exmeralda.Topics.{Chunk, Ingestion}

  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ingestion_id" => ingestion_id}}) do
    Repo.transact(fn ->
      with {:ok, ingestion} <- fetch_ingestion(ingestion_id) do
        case all_chunks_embedded?(ingestion_id) do
          :ok ->
            Topics.update_ingestion_state!(ingestion, :ready)
            {:ok, _} = Topics.mark_ingestion_as_active(ingestion.id)

          {:error, :embedding_not_finished} ->
            check_all_job_retries_exceeded(ingestion)
        end
      end
    end)
    |> case do
      {:error, :ingestion_not_found} ->
        {:cancel, :ingestion_not_found}

      {:error, {:ingestion_in_invalid_state, state}} ->
        {:cancel, {:ingestion_in_invalid_state, state}}

      {:error, :embedding_not_finished} ->
        {:snooze, 60}

      {:ok, _} ->
        :ok
    end
  end

  defp fetch_ingestion(ingestion_id) do
    case Repo.fetch(Ingestion, ingestion_id, lock: :no_key_update) do
      {:ok, %{state: :embedding} = ingestion} ->
        {:ok, ingestion}

      {:ok, %{state: state}} ->
        {:error, {:ingestion_in_invalid_state, state}}

      _ ->
        {:error, :ingestion_not_found}
    end
  end

  defp all_chunks_embedded?(ingestion_id) do
    query = from(c in Chunk, where: c.ingestion_id == ^ingestion_id and is_nil(c.embedding))

    if not Repo.exists?(query) do
      :ok
    else
      {:error, :embedding_not_finished}
    end
  end

  defp check_all_job_retries_exceeded(ingestion) do
    query =
      from(oj in Oban.Job,
        where:
          oj.worker == "Exmeralda.Topics.GenerateEmbeddingsWorker" and
            oj.state == "discarded" and
            oj.attempt >= oj.max_attempts and
            fragment("args->>'ingestion_id' = ?::text", ^ingestion.id)
      )

    if Repo.exists?(query) do
      {:ok, Topics.update_ingestion_state!(ingestion, :failed)}
    else
      {:error, :embedding_not_finished}
    end
  end
end
