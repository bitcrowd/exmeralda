defmodule ExmeraldaWeb.Admin.IngestionLiveTest do
  use ExmeraldaWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Exmeralda.Repo

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  defp insert_library(_) do
    %{library: insert(:library, name: "rag", version: "0.1.0")}
  end

  defp insert_ingestion(%{library: library}) do
    %{ingestion: insert(:ingestion, library: library, state: :ready)}
  end

  describe "authentication" do
    for route <- ["/admin/library/foo/ingestions/bar"] do
      test "is required for #{route}", %{conn: conn} do
        assert {:error,
                {:redirect, %{flash: %{"error" => "You must log in to access this page."}}}} =
                 live(conn, unquote(route))
      end
    end
  end

  describe "Show" do
    setup [:insert_user, :insert_library, :insert_ingestion]

    test "navigates to an ingestion from the library show view", %{
      conn: conn,
      user: user,
      library: library,
      ingestion: ingestion
    } do
      conn = log_in_user(conn, user)

      {:ok, show_library_live, html} =
        live(conn, ~p"/admin/library/#{library.id}")

      assert html =~ "Library rag 0.1.0"
      assert html =~ "Ingestions"

      assert {:error, {:live_redirect, %{to: path}}} =
               show_library_live
               |> element("a", "Show")
               |> render_click()

      assert path == "/admin/library/#{library.id}/ingestions/#{ingestion.id}"
    end

    test "deletes an ingestion", %{
      conn: conn,
      user: user,
      library: library,
      ingestion: ingestion
    } do
      chunk = insert(:chunk, ingestion: ingestion, library: library)
      conn = log_in_user(conn, user)

      {:ok, show_live, html} =
        live(conn, ~p"/admin/library/#{library.id}/ingestions/#{ingestion.id}")

      assert html =~ "Ingestion ##{ingestion.id} for rag 0.1.0"

      assert {:error, {:live_redirect, %{to: path}}} =
               show_live
               |> element("button", "Delete")
               |> render_click()

      assert path == "/admin/library/#{library.id}"
      refute Repo.reload(ingestion)
      refute Repo.reload(chunk)
    end

    for state <- [:queued, :embedding] do
      test "forbids deleting an ingestion in state #{state}", %{
        conn: conn,
        library: library,
        user: user
      } do
        ingestion = insert(:ingestion, state: unquote(state))

        conn = log_in_user(conn, user)

        {:ok, show_live, _html} =
          live(conn, ~p"/admin/library/#{library.id}/ingestions/#{ingestion.id}")

        assert has_element?(show_live, "button[disabled]", "Delete")
      end
    end

    test "forbids deleting an ingestion with chat sessions", %{
      conn: conn,
      library: library,
      user: user,
      ingestion: ingestion
    } do
      insert(:chat_session, ingestion: ingestion)
      conn = log_in_user(conn, user)

      {:ok, show_live, _html} =
        live(conn, ~p"/admin/library/#{library.id}/ingestions/#{ingestion.id}")

      assert has_element?(show_live, "button[disabled]", "Delete")
    end
  end
end
