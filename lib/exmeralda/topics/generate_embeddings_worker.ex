defmodule Exmeralda.Topics.GenerateEmbeddingsWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20

  alias Exmeralda.Repo
  alias Exmeralda.Topics.{Chunk, Rag}

  import Ecto.Query

  @embeddings_batch_size 20
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"library_id" => id}}) do
    from(c in Chunk, where: c.library_id == ^id, select: c.id)
    |> Repo.all()
    |> Enum.chunk_every(@embeddings_batch_size)
    |> Enum.map(&__MODULE__.new(%{chunk_ids: &1}))
    |> Oban.insert_all()

    :ok
  end

  def perform(%Oban.Job{args: %{"chunk_ids" => ids}}) do
    from(c in Chunk, where: c.id in ^ids)
    |> Repo.all()
    |> Rag.generate_embeddings()
    |> Enum.map(&Chunk.set_embedding(Map.put(&1, :embedding, nil), &1.embedding))
    |> Enum.each(&Repo.update!/1)

    :ok
  end
end
