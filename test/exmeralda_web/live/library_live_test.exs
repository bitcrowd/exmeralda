defmodule ExmeraldaWeb.LibraryLiveTest do
  use ExmeraldaWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Exmeralda.{Topics.IngestLibraryWorker}

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  describe "Index" do
    setup [:insert_user]

    test "add a new library", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, index_live, html} =
        live(conn, ~p"/library/new")

      assert html =~ "What next?"

      {:ok, _live, html} =
        form(index_live, "form", %{
          "library" => %{
            "name" => "ecto",
            "version" => "1.2.3"
          }
        })
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~
               "Your new library will be available in a few minutes! Thanks for participating."

      assert_enqueued(worker: IngestLibraryWorker, args: %{name: "ecto", version: "1.2.3"})
    end

    test "requires authentication", %{conn: conn} do
      assert {:error,
              {:redirect, %{to: "/", flash: %{"error" => "You must log in to access this page."}}}} =
               live(conn, ~p"/library/new")
    end
  end
end
