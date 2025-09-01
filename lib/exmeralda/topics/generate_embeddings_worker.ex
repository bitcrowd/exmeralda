defmodule Exmeralda.Topics.GenerateEmbeddingsWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20

  alias Exmeralda.Repo
  alias Exmeralda.Topics.{Chunk, Ingestion, Rag}

  import Ecto.Query

  def perform(%Oban.Job{args: %{"chunk_ids" => ids, "ingestion_id" => ingestion_id}}) do
    with {:ok, _ingestion} <- fetch_ingestion(ingestion_id),
         {:ok, embeddings} <- generate_embeddings(ids) do
      embeddings
      |> Enum.map(&Chunk.set_embedding(Map.put(&1, :embedding, nil), &1.embedding))
      |> Enum.each(&Repo.update!/1)

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

  defp generate_embeddings(chunk_ids) do
    try do
      embeddings =
        from(c in Chunk, where: c.id in ^chunk_ids)
        |> Repo.all()
        |> Rag.generate_embeddings()

      {:ok, embeddings}
    rescue
      error ->
        {:error, {:generate_embeddings, inspect(error)}}
    end
  end
end
