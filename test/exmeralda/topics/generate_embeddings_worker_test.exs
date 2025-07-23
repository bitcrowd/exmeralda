defmodule Exmeralda.Topics.GenerateEmbeddingsWorkerTest do
  use Exmeralda.DataCase
  alias Exmeralda.Topics.GenerateEmbeddingsWorker
  alias Exmeralda.Repo
  alias Exmeralda.Topics.Chunk
  import Ecto.Query

  def insert_library(_) do
    library = insert(:library)
    ingestion = insert(:ingestion, library: library, state: :embedding)
    chunks = insert_list(25, :chunk, ingestion: ingestion, library: library, embedding: nil)
    %{chunks: chunks, library: library, ingestion: ingestion}
  end

  describe "perform/1" do
    setup [:insert_library]

    test "generates embeddings for a library", %{
      library: library,
      chunks: chunks,
      ingestion: ingestion
    } do
      assert :ok =
               perform_job(GenerateEmbeddingsWorker, %{
                 library_id: library.id,
                 ingestion_id: ingestion.id
               })

      workers = all_enqueued(worker: GenerateEmbeddingsWorker)

      chunk_ids = Enum.map(workers, & &1.args["chunk_ids"])

      [5, 20] = chunk_ids |> Enum.map(&length/1) |> Enum.sort()

      chunk_ids = List.flatten(chunk_ids)

      for c <- chunks do
        assert c.id in chunk_ids
      end

      assert from(c in Chunk, where: is_nil(c.embedding)) |> Repo.aggregate(:count) == 25

      %{success: 2} = Oban.drain_queue(queue: :ingest)

      refute from(c in Chunk, where: is_nil(c.embedding)) |> Repo.one()
    end

    test "sets ingestion state to :ready when all chunks embedded", %{
      library: library,
      ingestion: ingestion
    } do
      assert ingestion.state == :embedding

      assert :ok =
               perform_job(GenerateEmbeddingsWorker, %{
                 library_id: library.id,
                 ingestion_id: ingestion.id
               })

      %{success: 2} = Oban.drain_queue(queue: :ingest)

      ingestion = Repo.reload(ingestion)

      assert ingestion.state == :ready
    end
  end
end
