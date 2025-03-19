defmodule ExmeraldaWeb.ChatLiveTest do
  use ExmeraldaWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Exmeralda.{Repo, Chat.Session}

  defp insert_session(_) do
    %{session: insert(:chat_session)}
  end

  describe "Index" do
    setup [:insert_session]

    test "list the sessions and greet", %{conn: conn, session: session} do
      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ session.id
      assert html =~ "Just ask Exmeralda"
    end

    test "start new session", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/")

      assert index_live |> element("#start-form") |> render_submit()

      html = render(index_live)
      assert html =~ "You underestimate my power!"
      assert Repo.aggregate(Session, :count) == 2
    end

    test "show a session", %{conn: conn, session: session} do
      {:ok, _show_live, html} = live(conn, ~p"/chats/#{session}")

      assert html =~ "You underestimate my power!"
    end
  end
end
