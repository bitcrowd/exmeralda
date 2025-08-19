defmodule Exmeralda.Topics.IngestLibraryWorkerTest do
  alias Exmeralda.Topics.GenerateEmbeddingsWorker
  use Exmeralda.DataCase

  alias Exmeralda.Topics.IngestLibraryWorker
  alias Exmeralda.Repo

  describe "perform/1 when ingestion does not exist" do
    test "cancels the worker" do
      assert perform_job(IngestLibraryWorker, %{ingestion_id: uuid()}) ==
               {:cancel, :ingestion_not_found}
    end
  end

  for state <- [:embedding, :failed, :ready] do
    describe "perform/1 when ingestion is in state #{state}" do
      test "cancels the worker" do
        ingestion = insert(:ingestion, state: unquote(state))

        assert perform_job(IngestLibraryWorker, %{ingestion_id: ingestion.id}) ==
                 {:cancel, {:ingestion_in_invalid_state, unquote(state)}}
      end
    end
  end

  describe "perform/1 when ingestion is in state queued" do
    setup do
      library = insert(:library, name: "rag", version: "0.1.0")
      ingestion = insert(:ingestion, state: :queued, library: library)
      %{ingestion: ingestion, library: library}
    end

    test "ingests a library and change state to embedding", %{
      ingestion: ingestion,
      library: library
    } do
      Req.Test.stub(Exmeralda.HexMock, fn conn ->
        body = Path.join("test/support/hex", conn.request_path) |> File.read!()

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/octet-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert perform_job(IngestLibraryWorker, %{ingestion_id: ingestion.id}) == :ok

      # ingestion moves to the next step
      ingestion = Repo.reload(ingestion)
      assert ingestion.state == :embedding

      # library got dependencies assigned
      library = Repo.reload(library) |> Repo.preload([:chunks])

      assert library.dependencies
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

      # Chunks were created
      assert length(library.chunks) > 350 and length(library.chunks) < 450
      docs = library.chunks |> Enum.filter(&(&1.type == :docs))
      code = library.chunks |> Enum.filter(&(&1.type == :code))
      assert length(docs) > 300 && length(docs) < 400
      assert length(code) > 50 && length(code) < 150
      assert Enum.all?(code, &String.starts_with?(&1.content, "# "))

      for source <- ["Rag.Telemetry.html", "mix.exs"] do
        assert chunk = Enum.find(library.chunks, &(&1.source == source))
        refute chunk.embedding
        assert is_binary(chunk.content)
      end

      # GenerateEmbeddingsWorker is enqueued and associated to ingestion
      job_id = ingestion.job_id

      assert_enqueued(
        id: job_id,
        worker: GenerateEmbeddingsWorker,
        args: %{library_id: library.id, ingestion_id: ingestion.id}
      )
    end

    test "discards non existant libs and marks ingestion as failed", %{ingestion: ingestion} do
      Req.Test.stub(Exmeralda.HexMock, fn conn ->
        Plug.Conn.send_resp(conn, 404, "")
      end)

      assert {:discard, {:repo_not_found, "/docs/rag-0.1.0.tar.gz"}} =
               perform_job(IngestLibraryWorker, %{ingestion_id: ingestion.id})

      assert Repo.reload(ingestion).state == :failed
      refute_enqueued(worker: GenerateEmbeddingsWorker)
    end

    test "errors if fetching from hex fails and does not mark ingestion as failed", %{
      ingestion: ingestion
    } do
      Req.Test.stub(Exmeralda.HexMock, fn conn ->
        Plug.Conn.send_resp(conn, 422, "")
      end)

      assert {:error, {:hex_fetch_error, %Req.Response{status: 422, body: ""}}} =
               perform_job(IngestLibraryWorker, %{ingestion_id: ingestion.id})

      assert Repo.reload(ingestion).state == :queued
      refute_enqueued(worker: GenerateEmbeddingsWorker)
    end
  end
end
