defmodule ExmeraldaWeb.ChatLiveTest do
  use ExmeraldaWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Exmeralda.{Repo, Chats.Session}

  defp insert_library(_) do
    %{library: insert(:library, name: "ecto")}
  end

  defp insert_session(%{user: user, library: library}) do
    %{session: insert(:chat_session, user: user, library: library)}
  end

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  describe "Index" do
    setup [:insert_library, :insert_user, :insert_session]

    test "list the sessions and greet", %{conn: conn, session: session, user: user} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/chat/start")

      assert html =~ session.id
      assert html =~ "Just ask Exmeralda"
    end

    test "does not show other users sessions", %{conn: conn, session: session} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(insert(:user))
        |> live(~p"/chat/start")

      refute html =~ session.id
      assert html =~ "Just ask Exmeralda"
    end

    test "start new session", %{conn: conn, user: user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/chat/start")

      assert index_live
             |> element("#start-form a", "ecto")
             |> render_click() =~ "ecto"

      assert element(index_live, "#start-form")
             |> render_submit()

      html = render(index_live)
      assert html =~ "You underestimate my power!"
      assert Repo.aggregate(Session, :count) == 2
    end

    test "show a session", %{conn: conn, session: session, user: user} do
      {:ok, _show_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/chat/#{session}")

      assert html =~ "You underestimate my power!"
    end

    test "requires authentication", %{conn: conn} do
      assert {:error,
              {:redirect, %{to: "/", flash: %{"error" => "You must log in to access this page."}}}} =
               live(conn, ~p"/chat/start")
    end
  end
end
