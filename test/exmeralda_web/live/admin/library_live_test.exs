defmodule ExmeraldaWeb.Admin.LibraryLiveTest do
  use ExmeraldaWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Exmeralda.Repo

  alias Exmeralda.Topics.{
    IngestLibraryWorker,
    Ingestion,
    EnqueueGenerateEmbeddingsWorker,
    GenerateEmbeddingsWorker,
    PollIngestionEmbeddingsWorker
  }

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  defp insert_library(_) do
    %{library: insert(:library, name: "rag", version: "0.1.0")}
  end

  describe "authentication" do
    for route <- ["/admin", "/admin/library/foo"] do
      test "is required for #{route}", %{conn: conn} do
        assert {:error,
                {:redirect, %{flash: %{"error" => "You must log in to access this page."}}}} =
                 live(conn, unquote(route))
      end
    end
  end

  describe "Index" do
    setup [:insert_user, :insert_library]

    test "list libraries", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _index_live, html} =
        live(conn, ~p"/admin")

      assert html =~ "rag"
      assert html =~ "0.1.0"
      assert html =~ "Libraries"
    end
  end

  describe "Show" do
    setup [:insert_user, :insert_library]

    test "delete a library, its ingestion and chunks", %{conn: conn, user: user, library: library} do
      ingestion = insert(:ingestion, library: library)
      chunk = insert(:chunk, ingestion: ingestion, library: library)

      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/admin/library/#{library.id}")

      assert html =~ "Library rag 0.1.0"
      assert html =~ "Ingestions"

      assert {:error, {:live_redirect, %{to: "/admin"}}} =
               view
               |> element("button", "Delete")
               |> render_click()

      refute Repo.reload(library)
      refute Repo.reload(ingestion)
      refute Repo.reload(chunk)
    end

    test "forbids deleting a library if it has chat sessions", %{
      conn: conn,
      user: user,
      library: library
    } do
      ingestion = insert(:ingestion, library: library)
      insert(:chat_session, ingestion: ingestion)

      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/admin/library/#{library.id}")

      assert html =~ "Library rag 0.1.0"
      assert html =~ "Ingestions"

      assert has_element?(view, "button[disabled]", "Delete")
    end

    test "reingest library", %{conn: conn, user: user, library: library} do
      Req.Test.stub(Exmeralda.HexMock, fn conn ->
        body = Path.join("test/support/hex", conn.request_path) |> File.read!()

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/octet-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/admin/library/#{library.id}")

      assert html =~ "Library rag 0.1.0"
      assert html =~ "Ingestions"

      view
      |> element("button", "Re-Ingest")
      |> render_click() =~ "Reingestion is now in queue!"

      ingestion = Repo.get_by!(Ingestion, library_id: library.id)
      assert ingestion.state == :queued

      assert_enqueued(worker: IngestLibraryWorker, args: %{ingestion_id: ingestion.id})
      %{success: 1, failure: 0} = Oban.drain_queue(queue: :ingest)

      ingestion = Repo.reload(ingestion)
      assert ingestion.state == :embedding

      assert_enqueued(
        worker: EnqueueGenerateEmbeddingsWorker,
        args: %{ingestion_id: ingestion.id}
      )

      %{success: 1, failure: 0} = Oban.drain_queue(queue: :ingest)

      ingestion = Repo.reload(ingestion)
      assert ingestion.state == :embedding

      assert_enqueued(worker: PollIngestionEmbeddingsWorker, args: %{ingestion_id: ingestion.id})

      # Chunks version
      assert all_enqueued(worker: GenerateEmbeddingsWorker, args: %{ingestion_id: ingestion.id})
             |> length() == 22

      %{success: 22, failure: 0} = Oban.drain_queue(queue: :ingest)

      assert all_enqueued(queue: :ingest) == []
      ingestion = Repo.reload(ingestion)
      assert ingestion.state == :embedding

      %{success: 1, failure: 0} = Oban.drain_queue(queue: :poll_ingestion)

      ingestion = Repo.reload(ingestion)
      assert ingestion.state == :ready
    end

    test "activate and deactivate an ingestion", %{conn: conn, user: user, library: library} do
      ingestion = insert(:ingestion, library: library, state: :ready, active: true)
      other_ingestion = insert(:ingestion, library: library, state: :ready, active: false)

      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/admin/library/#{library.id}")

      assert html =~ "Library rag 0.1.0"
      assert html =~ "Ingestions"

      view
      |> element(".e2e-activate-#{other_ingestion.id}", "Activate")
      |> render_click() =~ "Ingestion was successfully marked active."

      refute Repo.reload(ingestion).active
      assert Repo.reload(other_ingestion).active

      view
      |> element(".e2e-deactivate-#{other_ingestion.id}", "Deactivate")
      |> render_click() =~ "Ingestion was successfully marked inactive."

      # Both are inactive now
      refute Repo.reload(ingestion).active
      refute Repo.reload(other_ingestion).active

      view
      |> element(".e2e-activate-#{ingestion.id}", "Activate")
      |> render_click() =~ "Ingestion was successfully marked active."

      assert Repo.reload(ingestion).active
      refute Repo.reload(other_ingestion).active
    end
  end
end
