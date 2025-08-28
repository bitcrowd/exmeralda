defmodule Exmeralda.Topics.PollIngestionEmbeddingsWorkerTest do
  use Exmeralda.DataCase
  alias Exmeralda.Topics.{PollIngestionEmbeddingsWorker, GenerateEmbeddingsWorker}
  alias Exmeralda.Repo

  def insert_library(_) do
    library = insert(:library)
    ingestion = insert(:ingestion, library: library, state: :embedding)

    %{library: library, ingestion: ingestion}
  end

  describe "perform/1 when the ingestion does not exist" do
    test "cancels the job" do
      assert perform_job(PollIngestionEmbeddingsWorker, %{ingestion_id: uuid()}) ==
               {:cancel, :ingestion_not_found}
    end
  end

  for state <- [:queued, :failed, :ready] do
    describe "perform/1 when ingestion is in state #{state}" do
      test "cancels the worker" do
        ingestion = insert(:ingestion, state: unquote(state))

        assert perform_job(PollIngestionEmbeddingsWorker, %{ingestion_id: ingestion.id}) ==
                 {:cancel, {:ingestion_in_invalid_state, unquote(state)}}
      end
    end
  end

  describe "perform/1 when generating the embeddings is not finished" do
    setup [:insert_library]

    test "snoozes the worker", %{
      library: library,
      ingestion: ingestion
    } do
      insert(:chunk, ingestion: ingestion, library: library, embedding: nil)

      assert perform_job(PollIngestionEmbeddingsWorker, %{ingestion_id: ingestion.id}) ==
               {:snooze, 60}
    end

    test "marks the ingestion as failed if at least one worker has exceeded all attempts", %{
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

      Oban.insert(
        GenerateEmbeddingsWorker.new(%{
          ingestion_id: ingestion.id,
          chunk_ids: [chunk.id]
        })
      )

      Oban.insert(
        GenerateEmbeddingsWorker.new(%{
          ingestion_id: ingestion.id,
          chunk_ids: [failing_chunk.id]
        })
      )

      # One GenerateEmbeddingsWorker has failed!
      %{success: 1, failure: 1} = Oban.drain_queue(queue: :ingest)

      # Second job can retry so we continue to poll
      assert perform_job(PollIngestionEmbeddingsWorker, %{
               ingestion_id: ingestion.id
             }) == {:snooze, 60}

      # Let's retry the job again...
      for _n <- 1..18 do
        retry_job()
        %{success: 0, failure: 1} = Oban.drain_queue(queue: :ingest)
      end

      # Last retry, it is finally discarded
      retry_job()
      %{success: 0, failure: 0, discard: 1} = Oban.drain_queue(queue: :ingest)

      # Now if we poll again, we mark the ingestion as failed
      assert perform_job(PollIngestionEmbeddingsWorker, %{
               ingestion_id: ingestion.id
             }) == :ok

      ingestion = Repo.reload(ingestion)
      assert ingestion.state == :failed
    end
  end

  describe "perform/1 when generating the embeddings is finished" do
    setup [:insert_library]

    test "marks the ingestion as active and ready", %{
      library: library,
      ingestion: ingestion
    } do
      active_ingestion = insert(:ingestion, library: library, active: true, state: :ready)
      insert(:chunk, ingestion: ingestion, library: library)

      assert perform_job(PollIngestionEmbeddingsWorker, %{
               ingestion_id: ingestion.id
             }) == :ok

      ingestion = Repo.reload(ingestion)

      assert ingestion.state == :ready
      assert ingestion.active

      active_ingestion = Repo.reload(active_ingestion)
      refute active_ingestion.active
    end
  end

  defp retry_job do
    {:ok, 1} =
      Oban.Job
      |> Ecto.Query.where(state: "retryable")
      |> Oban.retry_all_jobs()
  end
end
