defmodule Exmeralda.Topics.GenerateEmbeddingsWorkerTest do
  use Exmeralda.DataCase
  alias Exmeralda.Topics.{GenerateEmbeddingsWorker, Chunk}
  alias Exmeralda.Repo
  import Ecto.Query

  def insert_ingestion(_) do
    library = insert(:library)
    %{ingestion: insert(:ingestion, library: library, state: :embedding)}
  end

  describe "perform/1 when the ingestion does not exist" do
    test "cancels the job" do
      assert perform_job(GenerateEmbeddingsWorker, %{chunk_ids: [uuid()], ingestion_id: uuid()}) ==
               {:cancel, :ingestion_not_found}
    end
  end

  for state <- [:queued, :failed, :ready] do
    describe "perform/1 when ingestion is in state #{state}" do
      test "cancels the worker" do
        ingestion = insert(:ingestion, state: unquote(state))

        assert perform_job(GenerateEmbeddingsWorker, %{
                 chunk_ids: [uuid()],
                 ingestion_id: ingestion.id
               }) ==
                 {:cancel, {:ingestion_in_invalid_state, unquote(state)}}
      end
    end
  end

  describe "perform/1 when generating the embeddings fails" do
    setup [:insert_ingestion]

    test "returns an error", %{ingestion: ingestion} do
      chunk = insert(:chunk, ingestion: ingestion, embedding: nil)

      # This chunk will cause Exmeralda.Rag.Fake to raise
      failing_chunk =
        insert(:chunk,
          ingestion: ingestion,
          embedding: nil,
          content: "please raise when running this embedding"
        )

      assert {:error, {:generate_embeddings, "%KeyError{key: nil, term: nil, message: nil}"}} =
               perform_job(GenerateEmbeddingsWorker, %{
                 chunk_ids: [chunk.id, failing_chunk.id],
                 ingestion_id: ingestion.id
               })

      # The chunks for this worker are still missing the embedding
      assert from(c in Chunk, where: is_nil(c.embedding)) |> Repo.aggregate(:count) == 2
    end
  end

  describe "perform/1 when generating the embeddings succeeds" do
    setup [:insert_ingestion]

    test "returns ok", %{ingestion: ingestion} do
      chunk = insert(:chunk, ingestion: ingestion, embedding: nil)

      assert perform_job(GenerateEmbeddingsWorker, %{
               chunk_ids: [chunk.id],
               ingestion_id: ingestion.id
             }) == :ok

      assert Repo.reload(chunk).embedding
    end
  end
end
