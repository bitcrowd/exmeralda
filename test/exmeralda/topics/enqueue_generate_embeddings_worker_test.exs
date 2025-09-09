defmodule Exmeralda.Topics.EnqueueGenerateEmbeddingsWorkerTest do
  use Exmeralda.DataCase

  alias Exmeralda.Topics.{
    EnqueueGenerateEmbeddingsWorker,
    GenerateEmbeddingsWorker,
    Chunk
  }

  alias Exmeralda.Repo
  import Ecto.Query

  def insert_ingestion(_) do
    %{ingestion: insert(:ingestion, library: insert(:library), state: :embedding)}
  end

  describe "perform/1 when the ingestion does not exist" do
    test "cancels the job" do
      assert perform_job(EnqueueGenerateEmbeddingsWorker, %{ingestion_id: uuid()}) ==
               {:cancel, :ingestion_not_found}
    end
  end

  for state <- [:queued, :failed, :ready] do
    describe "perform/1 when ingestion is in state #{state}" do
      test "cancels the worker" do
        ingestion = insert(:ingestion, state: unquote(state))

        assert perform_job(EnqueueGenerateEmbeddingsWorker, %{ingestion_id: ingestion.id}) ==
                 {:cancel, {:ingestion_in_invalid_state, unquote(state)}}
      end
    end
  end

  describe "perform/1" do
    setup [:insert_ingestion]

    setup %{ingestion: ingestion} do
      %{
        chunks:
          insert_list(25, :chunk,
            ingestion: ingestion,
            embedding: nil
          )
      }
    end

    test "activates and sets ingestion state to :ready when all chunks embedded", %{
      ingestion: ingestion,
      chunks: chunks
    } do
      active_ingestion =
        insert(:ingestion, library: ingestion.library, active: true, state: :ready)

      assert :ok = perform_job(EnqueueGenerateEmbeddingsWorker, %{ingestion_id: ingestion.id})

      workers =
        all_enqueued(
          queue: :ingest,
          worker: GenerateEmbeddingsWorker,
          args: %{ingestion_id: ingestion.id}
        )

      assert length(workers) == 2

      chunk_ids = Enum.map(workers, & &1.args["chunk_ids"])
      [5, 20] = chunk_ids |> Enum.map(&length/1) |> Enum.sort()
      chunk_ids = List.flatten(chunk_ids)

      for c <- chunks do
        assert c.id in chunk_ids
      end

      assert from(c in Chunk, where: is_nil(c.embedding)) |> Repo.aggregate(:count) == 25

      %{success: 2, failure: 0, snoozed: 0} = Oban.drain_queue(queue: :ingest)

      refute from(c in Chunk, where: is_nil(c.embedding)) |> Repo.one()

      ingestion = Repo.reload(ingestion)
      assert ingestion.state == :ready
      assert ingestion.active

      active_ingestion = Repo.reload(active_ingestion)
      refute active_ingestion.active
    end

    test "sets ingestion state to :failed when some chunks fail to be embedded", %{
      ingestion: ingestion
    } do
      active_ingestion =
        insert(:ingestion, library: ingestion.library, active: true, state: :ready)

      # This chunk will cause Exmeralda.Rag.Fake to raise
      insert(:chunk,
        ingestion: ingestion,
        embedding: nil,
        content: "please raise when running this embedding"
      )

      assert :ok = perform_job(EnqueueGenerateEmbeddingsWorker, %{ingestion_id: ingestion.id})

      assert all_enqueued(worker: GenerateEmbeddingsWorker, args: %{ingestion_id: ingestion.id})
             |> length() == 2

      # one GenerateEmbeddingsWorker fails, one succeeds
      %{success: 1, failure: 1} = Oban.drain_queue(queue: :ingest)

      # Ingestion still embedding
      ingestion = Repo.reload(ingestion)
      assert ingestion.state == :embedding
      refute ingestion.active

      # Let's retry the jobs again...
      for _n <- 1..18 do
        retry_job()
        %{success: 0, failure: 1, snoozed: 0} = Oban.drain_queue(queue: :ingest)
      end

      # One last attempt
      retry_job()
      %{success: 0, failure: 0, discard: 1} = Oban.drain_queue(queue: :ingest)

      ingestion = Repo.reload(ingestion)

      assert ingestion.state == :failed
      refute ingestion.active

      assert Repo.reload(active_ingestion).active
    end
  end
end
