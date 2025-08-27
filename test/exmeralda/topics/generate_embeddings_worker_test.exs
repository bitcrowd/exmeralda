defmodule Exmeralda.Topics.GenerateEmbeddingsWorkerTest do
  use Exmeralda.DataCase
  alias Exmeralda.Topics.{GenerateEmbeddingsWorker, PollIngestionEmbeddingsWorker, Chunk}
  alias Exmeralda.Repo
  import Ecto.Query

  def insert_library(_) do
    library = insert(:library)
    ingestion = insert(:ingestion, library: library, state: :embedding)

    %{library: library, ingestion: ingestion}
  end

  describe "perform/1 with library_id when the ingestion does not exist" do
    test "cancels the job" do
      assert perform_job(GenerateEmbeddingsWorker, %{library_id: uuid(), ingestion_id: uuid()}) ==
               {:cancel, :ingestion_not_found}
    end
  end

  describe "perform/1 with library_id when the ingestion does not belong to the library" do
    test "cancels the job" do
      ingestion = insert(:ingestion, state: :embedding)

      assert perform_job(GenerateEmbeddingsWorker, %{
               library_id: uuid(),
               ingestion_id: ingestion.id
             }) == {:cancel, :ingestion_not_found}
    end
  end

  for state <- [:queued, :failed, :ready] do
    describe "perform/1 with library_id when ingestion is in state #{state}" do
      test "cancels the worker" do
        ingestion = insert(:ingestion, state: unquote(state))

        assert perform_job(GenerateEmbeddingsWorker, %{
                 ingestion_id: ingestion.id,
                 library_id: ingestion.library_id
               }) ==
                 {:cancel, {:ingestion_in_invalid_state, unquote(state)}}
      end
    end
  end

  describe "perform/1 with library_id" do
    setup [:insert_library]

    setup %{ingestion: ingestion} do
      %{
        chunks:
          insert_list(25, :chunk,
            ingestion: ingestion,
            embedding: nil
          )
      }
    end

    test "generates embeddings for a library", %{
      library: library,
      ingestion: ingestion,
      chunks: chunks
    } do
      assert :ok =
               perform_job(GenerateEmbeddingsWorker, %{
                 library_id: library.id,
                 ingestion_id: ingestion.id
               })

      assert_enqueued(worker: PollIngestionEmbeddingsWorker, args: %{ingestion_id: ingestion.id})

      workers = all_enqueued(worker: GenerateEmbeddingsWorker)

      chunk_ids = Enum.map(workers, & &1.args["chunk_ids"])

      [5, 20] = chunk_ids |> Enum.map(&length/1) |> Enum.sort()

      chunk_ids = List.flatten(chunk_ids)

      for c <- chunks do
        assert c.id in chunk_ids
      end

      assert from(c in Chunk, where: is_nil(c.embedding)) |> Repo.aggregate(:count) == 25

      %{success: 3, failure: 0, snoozed: 0} = Oban.drain_queue(queue: :ingest)

      refute from(c in Chunk, where: is_nil(c.embedding)) |> Repo.one()
    end

    test "activates and sets ingestion state to :ready when all chunks embedded", %{
      library: library,
      ingestion: ingestion
    } do
      active_ingestion = insert(:ingestion, library: library, active: true, state: :ready)

      assert :ok =
               perform_job(GenerateEmbeddingsWorker, %{
                 library_id: library.id,
                 ingestion_id: ingestion.id
               })

      assert_enqueued(worker: PollIngestionEmbeddingsWorker, args: %{ingestion_id: ingestion.id})

      assert all_enqueued(worker: GenerateEmbeddingsWorker, args: %{ingestion_id: ingestion.id})
             |> length() == 2

      %{success: 3, failure: 0, snoozed: 0} = Oban.drain_queue(queue: :ingest)

      ingestion = Repo.reload(ingestion)

      assert ingestion.state == :ready
      assert ingestion.active

      active_ingestion = Repo.reload(active_ingestion)
      refute active_ingestion.active
    end

    test "sets ingestion state to :failed when some chunks fail to be embedded", %{
      library: library,
      ingestion: ingestion
    } do
      active_ingestion = insert(:ingestion, library: library, active: true, state: :ready)

      # This chunk will cause Exmeralda.Rag.Fake to raise
      insert(:chunk,
        ingestion: ingestion,
        library: library,
        embedding: nil,
        content: "please raise when running this embedding"
      )

      assert :ok =
               perform_job(GenerateEmbeddingsWorker, %{
                 library_id: library.id,
                 ingestion_id: ingestion.id
               })

      assert_enqueued(worker: PollIngestionEmbeddingsWorker, args: %{ingestion_id: ingestion.id})

      assert all_enqueued(worker: GenerateEmbeddingsWorker, args: %{ingestion_id: ingestion.id})
             |> length() == 2

      # one GenerateEmbeddingsWorker fails, one succeeds, PollIngestionEmbeddingsWorker is snoozed
      %{success: 1, failure: 1, snoozed: 1} = Oban.drain_queue(queue: :ingest)

      ingestion = Repo.reload(ingestion)

      assert ingestion.state == :embedding
      refute ingestion.active

      all_enqueued(worker: PollIngestionEmbeddingsWorker)

      # Let's retry the jobs again...
      for _n <- 1..18 do
        retry_job()
        %{success: 0, failure: 1, snoozed: 1} = Oban.drain_queue(queue: :ingest)
      end

      # One last attempt
      retry_job()
      %{success: 1, failure: 0, discard: 1} = Oban.drain_queue(queue: :ingest)

      ingestion = Repo.reload(ingestion)

      assert ingestion.state == :failed
      refute ingestion.active

      assert Repo.reload(active_ingestion).active
    end
  end

  describe "perform/1 with chunk_ids when the ingestion does not exist" do
    test "cancels the job" do
      assert perform_job(GenerateEmbeddingsWorker, %{chunk_ids: [uuid()], ingestion_id: uuid()}) ==
               {:cancel, :ingestion_not_found}
    end
  end

  for state <- [:queued, :failed, :ready] do
    describe "perform/1 with chunk_ids when ingestion is in state #{state}" do
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

  describe "perform/1 with chunk_ids when generating the embeddings fails" do
    setup [:insert_library]

    test "returns an error", %{
      library: library,
      ingestion: ingestion
    } do
      chunk = insert(:chunk, ingestion: ingestion, library: library, embedding: nil)

      # This chunk will cause Exmeralda.Rag.Fake to raise
      failing_chunk =
        insert(:chunk,
          ingestion: ingestion,
          library: library,
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

  describe "perform/1 with chunk_ids when generating the embeddings succeeds" do
    setup [:insert_library]

    test "returns ok", %{
      library: library,
      ingestion: ingestion
    } do
      chunk = insert(:chunk, ingestion: ingestion, library: library, embedding: nil)

      assert perform_job(GenerateEmbeddingsWorker, %{
               chunk_ids: [chunk.id],
               ingestion_id: ingestion.id
             }) == :ok

      assert Repo.reload(chunk).embedding
    end
  end

  defp retry_job do
    {:ok, 2} =
      Oban.Job
      |> Ecto.Query.where([o], o.state in ["scheduled", "retryable"])
      |> Oban.retry_all_jobs()
  end
end
