defmodule Exmeralda.Topics.IngestLibraryWorkerTest do
  alias Exmeralda.Topics.GenerateEmbeddingsWorker
  use Exmeralda.DataCase

  alias Exmeralda.Topics.{IngestLibraryWorker, Library}
  alias Exmeralda.Repo

  describe "perform/1" do
    test "ingests a libray" do
      Req.Test.stub(Exmeralda.HexMock, fn conn ->
        body = Path.join("test/support/hex", conn.request_path) |> File.read!()

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/octet-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert :ok = perform_job(IngestLibraryWorker, %{name: "rag", version: "0.1.0"})

      assert rag = Repo.get_by(Library, name: "rag", version: "0.1.0") |> Repo.preload(:chunks)

      assert rag.dependencies
             |> Enum.map(&{&1.name, &1.version_requirement, optional: &1.optional})
             |> Enum.sort() == [
               {"exla", "~> 0.9.1", [optional: true]},
               {"igniter", "~> 0.4", [optional: false]},
               {"jason", "~> 1.4", [optional: false]},
               {"langchain", "~> 0.3.0-rc.0", [optional: true]},
               {"nx", "~> 0.9.0", [optional: true]},
               {"req", "~> 0.5.0", [optional: false]},
               {"telemetry", "~> 1.0", [optional: false]},
               {"text_chunker", "~> 0.3.1", [optional: false]}
             ]

      assert length(rag.chunks) > 350 and length(rag.chunks) < 450
      docs = rag.chunks |> Enum.filter(&(&1.type == :docs))
      code = rag.chunks |> Enum.filter(&(&1.type == :code))
      assert length(docs) > 300 && length(docs) < 400
      assert length(code) > 50 && length(code) < 150
      assert Enum.all?(code, &String.starts_with?(&1.content, "# "))

      for source <- ["Rag.Telemetry.html", "mix.exs"] do
        assert chunk = Enum.find(rag.chunks, &(&1.source == source))
        refute chunk.embedding
        assert is_binary(chunk.content)
      end

      assert_enqueued(worker: GenerateEmbeddingsWorker, args: %{library_id: rag.id})
    end

    test "discards non existant libs" do
      Req.Test.stub(Exmeralda.HexMock, fn conn ->
        Plug.Conn.send_resp(conn, 404, "")
      end)

      assert {:discard, {:repo_not_found, "/docs/rag-0.1.0.tar.gz"}} =
               perform_job(IngestLibraryWorker, %{name: "rag", version: "0.1.0"})
    end
  end
end
