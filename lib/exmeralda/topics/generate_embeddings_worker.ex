defmodule Exmeralda.Topics.GenerateEmbeddingsWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20

  alias Exmeralda.Repo
  alias Exmeralda.Topics
  alias Exmeralda.Topics.{Chunk, Ingestion, Rag}

  import Ecto.Query

  @embeddings_batch_size 20
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"library_id" => id, "ingestion_id" => ingestion_id}}) do
    from(c in Chunk, where: c.library_id == ^id, select: c.id)
    |> Repo.all()
    |> Enum.chunk_every(@embeddings_batch_size)
    |> Enum.map(&__MODULE__.new(%{chunk_ids: &1, ingestion_id: ingestion_id}))
    |> Oban.insert_all()

    :ok
  end

  def perform(%Oban.Job{args: %{"chunk_ids" => ids, "ingestion_id" => ingestion_id}}) do
    from(c in Chunk, where: c.id in ^ids)
    |> Repo.all()
    |> Rag.generate_embeddings()
    |> Enum.map(&Chunk.set_embedding(Map.put(&1, :embedding, nil), &1.embedding))
    |> Enum.each(&Repo.update!/1)

    if all_chunks_embedded?(ingestion_id) do
      Repo.get!(Ingestion, ingestion_id)
      |> Topics.update_ingestion_state!(:ready)
    end

    :ok
  end

  defp all_chunks_embedded?(ingestion_id) do
    query = from(c in Chunk, where: c.ingestion_id == ^ingestion_id and is_nil(c.embedding))

    not Repo.exists?(query)
  end
end
