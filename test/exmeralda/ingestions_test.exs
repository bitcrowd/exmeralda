defmodule Exmeralda.IngestionsTest do
  use Exmeralda.DataCase
  alias Exmeralda.Ingestions
  alias Exmeralda.Topics.{Chunk, GenerateEmbeddingsWorker}

  describe "set_preprocessing/1" do
    test "sets the ingestion state to preprocessing" do
      {:ok, ingestion} =
        insert(:ingestion, state: :queued)
        |> Ingestions.set_preprocessing()

      assert %{state: :preprocessing} = ingestion
    end
  end

  describe "set_chunking/1" do
    test "sets the ingestion state to chunking" do
      Req.Test.stub(Exmeralda.HexMock, fn conn ->
        body = Path.join("test/support/hex", conn.request_path) |> File.read!()

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/octet-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      ingestion =
        insert(:ingestion,
          state: :preprocessing,
          library: insert(:library, name: "rag", version: "0.1.0")
        )

      {:ok, %{ingestion: ingestion, args: _args}} = Ingestions.set_chunking(ingestion)

      assert %{state: :chunking} = ingestion
    end
  end

  describe "set_embedding/2" do
    test "sets the ingestion state to embedding" do
      {:ok, ingestion} =
        insert(:ingestion, state: :chunking)
        |> Ingestions.set_embedding(%{docs: [], code: []})

      assert %{state: :embedding} = ingestion
    end

    test "inserts chunks" do
      docs = [%{source: "ingestion_test.exs", content: "example documentation string"}]

      code = [
        %{
          source: "ingestion_test.exs",
          content: "defmodule Ingestion do\n  def ingest(data) do\n    {:ok, data}\n  end\nend"
        }
      ]

      {:ok, ingestion} =
        insert(:ingestion, state: :chunking)
        |> Ingestions.set_embedding(%{docs: docs, code: code})

      assert [
               %{
                 source: "ingestion_test.exs",
                 type: :docs,
                 content: "example documentation string"
               },
               %{
                 source: "ingestion_test.exs",
                 type: :code,
                 content:
                   "# ingestion_test.exs\n\ndefmodule Ingestion do\n  def ingest(data) do\n    {:ok, data}\n  end\nend"
               }
             ] = Repo.all(Chunk)

      assert %{state: :embedding} = ingestion
    end
  end

  describe "schedule_embeddings_worker/1" do
    test "schedules the embeddings worker" do
      ingestion = insert(:ingestion, state: :embedding)
      Ingestions.schedule_embeddings_worker(ingestion)

      assert_enqueued(
        worker: GenerateEmbeddingsWorker,
        args: %{ingestion_id: ingestion.id, library_id: ingestion.library_id}
      )
    end
  end
end
