defmodule ExmeraldaWeb.ChatLiveTest do
  use ExmeraldaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias Exmeralda.Repo
  alias Exmeralda.Chats.{Reaction, Session}

  defp insert_library(_) do
    library = insert(:library, name: "ecto")
    ingestion = insert(:ingestion, library: library, state: :ready, active: true)

    %{library: library, ingestion: ingestion}
  end

  defp insert_session(%{user: user, library: library, ingestion: ingestion}) do
    %{
      session:
        insert(:chat_session,
          user: user,
          library: library,
          ingestion: ingestion,
          messages: [
            build(:message, role: :user, index: 0, session: nil),
            build(:message, role: :assistant, index: 1, session: nil)
          ]
        )
    }
  end

  defp insert_user(_) do
    %{user: insert(:user)}
  end

  defp insert_llm_config(_) do
    provider = insert(:provider, type: :mock)
    model_config = insert(:model_config)

    insert(:model_config_provider,
      model_config: model_config,
      provider: provider,
      id: test_model_config_provider_id()
    )

    insert(:system_prompt, id: test_system_prompt_id())
    insert(:generation_prompt, id: test_generation_prompt_id())

    :ok
  end

  describe "Index" do
    setup [:insert_llm_config, :insert_library, :insert_user, :insert_session]

    test "list the sessions and greet", %{conn: conn, session: session, user: user} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/chat/start")

      assert html =~ session.id
      assert html =~ "Ask Exmeralda"
    end

    test "does not show other users sessions", %{conn: conn, session: session} do
      user = insert(:user)

      {:ok, _index_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/chat/start")

      refute html =~ session.id
      assert html =~ "Ask Exmeralda"

      assert_raise Ecto.NoResultsError, fn ->
        conn
        |> log_in_user(user)
        |> live(~p"/chat/#{session}")
      end
    end

    test "does not show sessions with nilified users", %{conn: conn, user: user} do
      session = insert(:chat_session, user_id: nil)

      {:ok, _index_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/chat/start")

      refute html =~ session.id
      assert html =~ "Ask Exmeralda"
    end

    test "start new session", %{conn: conn, user: user, library: library} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/chat/start")

      assert index_live
             |> element("#start-form a", "ecto")
             |> render_click() =~ "ecto"

      assert form(index_live, "#start-form", %{
               "session" => %{
                 "prompt" => "You underestimate my power!",
                 "library_id" => library.id
               }
             })
             |> render_submit()

      html = render(index_live)
      assert html =~ "You underestimate my power!"

      wait_for_generation_task()

      assert Repo.aggregate(Session, :count) == 2
    end

    test "show a session", %{conn: conn, session: session, user: user} do
      {:ok, _show_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/chat/#{session}")

      assert html =~ "I am a message"
    end

    test "delete a session", %{conn: conn, session: session, user: user} do
      {:ok, index_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/chat/start")

      assert html =~ session.id

      assert index_live |> element(".e2e-delete-session-#{session.id}") |> render_click()

      refute Repo.reload(session).user_id

      html = render(index_live)
      refute html =~ session.id
    end

    test "requires authentication", %{conn: conn} do
      assert {:error,
              {:redirect, %{to: "/", flash: %{"error" => "You must log in to access this page."}}}} =
               live(conn, ~p"/chat/start")
    end

    test "users can up and downvote messages and undo their votes", %{
      conn: conn,
      user: user,
      session: session
    } do
      [_, message] = session.messages

      {:ok, chat_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/chat/#{session}")

      assert html =~ "I am a message"

      assert chat_live |> element(".e2e-upvote-message-#{message.id}") |> render_click()

      [reaction] = Repo.all(Reaction)
      assert reaction.message_id == message.id
      assert reaction.type == :upvote

      assert chat_live |> element(".e2e-downvote-message-#{message.id}") |> render_click()

      reaction = Repo.reload(reaction)
      assert reaction.type == :downvote

      assert chat_live |> element(".e2e-downvote-message-#{message.id}") |> render_click()
      assert Repo.all(Reaction) == []
    end
  end
end
