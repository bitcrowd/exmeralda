defmodule Exmeralda.Topics.GenerateEmbeddingsWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20

  alias Exmeralda.Repo
  alias Exmeralda.Topics.{Chunk, Ingestion, Rag}
  alias Exmeralda.Topics

  import Ecto.Query

  def perform(%Oban.Job{args: %{"chunk_ids" => ids, "ingestion_id" => ingestion_id}} = job) do
    with {:ok, ingestion} <- fetch_ingestion(ingestion_id),
         {:ok, embeddings} <- generate_embeddings(ids, ingestion, job) do
      embeddings
      |> Enum.map(&Chunk.set_embedding(Map.put(&1, :embedding, nil), &1.embedding))
      |> Enum.each(&Repo.update!/1)

      if all_chunks_embedded?(ingestion.id) do
        ingestion = Topics.update_ingestion_state!(ingestion, :ready)
        {:ok, _} = Topics.mark_ingestion_as_active(ingestion.id)
      end

      :ok
    end
  end

  defp fetch_ingestion(ingestion_id) do
    case Repo.get(Ingestion, ingestion_id) do
      %{state: :embedding} = ingestion ->
        {:ok, ingestion}

      %{state: state} ->
        {:cancel, {:ingestion_in_invalid_state, state}}

      _ ->
        {:cancel, :ingestion_not_found}
    end
  end

  defp generate_embeddings(chunk_ids, ingestion, job) do
    try do
      embeddings =
        from(c in Chunk, where: c.id in ^chunk_ids and is_nil(c.embedding))
        |> Repo.all()
        |> Rag.generate_embeddings()

      {:ok, embeddings}
    rescue
      error ->
        if job.attempt >= job.max_attempts do
          Topics.update_ingestion_state!(ingestion, :failed)
        end

        {:error, {:generate_embeddings, inspect(error)}}
    end
  end

  defp all_chunks_embedded?(ingestion_id) do
    query = from(c in Chunk, where: c.ingestion_id == ^ingestion_id and is_nil(c.embedding))

    not Repo.exists?(query)
  end
end
