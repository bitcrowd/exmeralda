defmodule Exmeralda.Topics.GenerateEmbeddingsWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20

  alias Exmeralda.Repo
  alias Exmeralda.Topics.{Chunk, Ingestion, Rag, PollIngestionEmbeddingsWorker}

  import Ecto.Query

  @embeddings_batch_size 20

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{"library_id" => library_id, "ingestion_id" => ingestion_id}
      }) do
    Repo.transact(fn ->
      with {:ok, ingestion} <- fetch_ingestion(ingestion_id, library_id: library_id) do
        from(c in Chunk, where: c.ingestion_id == ^ingestion_id, select: c.id)
        |> Repo.all()
        |> Enum.chunk_every(@embeddings_batch_size)
        |> Enum.map(
          # Passing the parent job_id so it's easier to find which children chunk jobs
          # were enqueued by this worker.
          &__MODULE__.new(%{chunk_ids: &1, ingestion_id: ingestion.id, parent_job_id: id})
        )
        |> Oban.insert_all()

        Oban.insert(
          PollIngestionEmbeddingsWorker.new(%{ingestion_id: ingestion.id, parent_job_id: id})
        )
      end
    end)
    |> case do
      {:error, :ingestion_not_found} ->
        {:cancel, :ingestion_not_found}

      {:error, {:ingestion_in_invalid_state, state}} ->
        {:cancel, {:ingestion_in_invalid_state, state}}

      {:ok, _} ->
        :ok
    end
  end

  def perform(%Oban.Job{args: %{"chunk_ids" => ids, "ingestion_id" => ingestion_id}}) do
    with {:ok, _ingestion} <- fetch_ingestion(ingestion_id),
         {:ok, embeddings} <- generate_embeddings(ids) do
      embeddings
      |> Enum.map(&Chunk.set_embedding(Map.put(&1, :embedding, nil), &1.embedding))
      |> Enum.each(&Repo.update!/1)

      :ok
    else
      {:error, :ingestion_not_found} ->
        {:cancel, :ingestion_not_found}

      {:error, {:ingestion_in_invalid_state, state}} ->
        {:cancel, {:ingestion_in_invalid_state, state}}

      {:error, {:generate_embeddings, error}} ->
        {:error, {:generate_embeddings, inspect(error)}}
    end
  end

  defp fetch_ingestion(ingestion_id, opts \\ []) do
    case Repo.get(Ingestion, ingestion_id) do
      %{state: :embedding} = ingestion ->
        check_library_id(ingestion, Keyword.get(opts, :library_id))

      %{state: state} ->
        {:error, {:ingestion_in_invalid_state, state}}

      _ ->
        {:error, :ingestion_not_found}
    end
  end

  defp check_library_id(%{library_id: library_id} = ingestion, library_id),
    do: check_library_id(ingestion, nil)

  defp check_library_id(ingestion, nil), do: {:ok, Repo.preload(ingestion, [:library])}
  defp check_library_id(_, _), do: {:error, :ingestion_not_found}

  defp generate_embeddings(chunk_ids) do
    try do
      embeddings =
        from(c in Chunk, where: c.id in ^chunk_ids)
        |> Repo.all()
        |> Rag.generate_embeddings()

      {:ok, embeddings}
    rescue
      error ->
        {:error, {:generate_embeddings, error}}
    end
  end
end
