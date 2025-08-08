defmodule ExmeraldaWeb.LibraryLiveTest do
  use ExmeraldaWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Exmeralda.Repo
  alias Exmeralda.Topics.{IngestLibraryWorker, Library}

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  describe "Index" do
    setup [:insert_user]

    test "add a new library", %{conn: conn, user: user} do
      Req.Test.stub(Exmeralda.HexMock, fn conn ->
        body = Path.join("test/support/hex", conn.request_path) |> File.read!()

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/octet-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      conn = log_in_user(conn, user)

      {:ok, index_live, _html} =
        live(conn, ~p"/library/new")

      html = render_async(index_live)

      assert html =~ "What next?"

      _html =
        form(index_live, "#start-form", %{
          "library" => %{
            "name" => "ecto"
          }
        })
        |> render_change()

      {:ok, _live, html} =
        form(index_live, "#start-form", %{
          "library" => %{
            "version" => "3.13.0"
          }
        })
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~
               "Your new library will be available in a few minutes! Thanks for participating."

      assert html =~ "Current Ingestions"

      library =
        Repo.get_by!(Library, name: "ecto", version: "3.13.0") |> Repo.preload(:ingestions)

      assert [ingestion] = library.ingestions

      assert_enqueued(worker: IngestLibraryWorker, args: %{ingestion_id: ingestion.id})
    end

    test "requires authentication", %{conn: conn} do
      assert {:error,
              {:redirect, %{to: "/", flash: %{"error" => "You must log in to access this page."}}}} =
               live(conn, ~p"/library/new")
    end
  end
end
