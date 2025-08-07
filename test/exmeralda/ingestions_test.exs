defmodule Exmeralda.IngestionsTest do
  use Exmeralda.DataCase
  alias Exmeralda.Ingestions
  alias Exmeralda.Topics.{Chunk, GenerateEmbeddingsWorker}

  describe "preprocess/1" do
    test "retrieves docs and code for library, updates library with dependencies" do
      Req.Test.stub(Exmeralda.HexMock, fn conn ->
        body = Path.join("test/support/hex", conn.request_path) |> File.read!()

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/octet-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      library = insert(:library, name: "rag", version: "0.1.0", dependencies: [])

      ingestion =
        insert(:ingestion,
          state: :preprocessing,
          library: library
        )

      {:ok, documents} = Ingestions.preprocess(ingestion)

      assert Enum.any?(documents, fn document -> document.type == :docs end)
      assert Enum.any?(documents, fn document -> document.type == :code end)

      library = Repo.reload(library)
      assert library.dependencies
    end
  end

  describe "chunk_and_insert_documents/2" do
    test "inserts chunks" do
      docs = [
        %{source: "ingestion_test.exs", content: "example documentation string", type: :docs}
      ]

      code = [
        %{
          source: "ingestion_test.exs",
          content: "defmodule Ingestion do\n  def ingest(data) do\n    {:ok, data}\n  end\nend",
          type: :code
        }
      ]

      ingestion = insert(:ingestion, state: :chunking)

      assert :ok = Ingestions.chunk_and_insert_documents(ingestion, docs ++ code)

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
                   "# ingestion_test.exs\n\ndefmodule Ingestion do\n  def ingest(data) do\n    {:ok, data}\n  end\nend\n"
               }
             ] = Repo.all(Chunk)
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
