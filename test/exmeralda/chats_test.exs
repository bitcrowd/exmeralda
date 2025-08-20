defmodule Exmeralda.ChatsTest do
  use Exmeralda.DataCase, async: false

  alias Exmeralda.Chats
  alias Exmeralda.Chats.{Message, Session, Reaction}
  alias Exmeralda.Repo

  def insert_user(_) do
    %{user: insert(:user)}
  end

  describe "list_sessions/1" do
    setup [:insert_user]

    setup %{user: user} do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)

      %{
        new_session: insert(:chat_session, user: user, ingestion: ingestion),
        old_session:
          insert(:chat_session,
            user: user,
            ingestion: ingestion,
            inserted_at: DateTime.utc_now() |> DateTime.add(-10)
          )
      }
    end

    test "returns the user sessions, sorted desc by inserted_at", %{
      user: user,
      new_session: new_session,
      old_session: old_session
    } do
      assert [a, b] = Chats.list_sessions(user)
      assert a.id == new_session.id
      assert b.id == old_session.id
    end

    test "scopes by user" do
      assert Chats.list_sessions(insert(:user)) == []
    end

    test "preloads the library", %{user: user} do
      assert [a, b] = Chats.list_sessions(user)
      assert_preloaded(a, :library)
      assert_preloaded(b, :library)
    end
  end

  describe "get_session!/2" do
    setup [:insert_user]

    setup %{user: user} do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)

      %{
        session: insert(:chat_session, user: user, ingestion: ingestion),
        library: library,
        ingestion: ingestion
      }
    end

    test "raises if the session does not belong to the user", %{session: session} do
      assert_raise Ecto.NoResultsError, fn -> Chats.get_session!(insert(:user), session.id) end
    end

    test "raises if the session does not exist" do
      assert_raise Ecto.NoResultsError, fn -> Chats.get_session!(insert(:user), uuid()) end
    end

    test "returns the session by user and session ID and preloads library, messages", %{
      session: session,
      user: user
    } do
      assert result = Chats.get_session!(user, session.id)
      assert result.id == session.id
      assert_preloaded(result, :library)
      assert_preloaded(result, :messages)
    end

    test "preloads the messages source chunks", %{
      session: session,
      user: user,
      library: library,
      ingestion: ingestion
    } do
      chunk = insert(:chunk, library: library, ingestion: ingestion)
      insert(:chat_source, chunk: chunk, message: insert(:message, session: session))

      assert result = Chats.get_session!(user, session.id)
      [message] = result.messages
      assert_preloaded(message, :source_chunks)
    end
  end

  describe "get_message!/1" do
    test "raises if the message does not exist" do
      assert_raise Ecto.NoResultsError, fn -> Chats.get_message!(uuid()) end
    end

    test "returns the message and preloads the messages source chunks" do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)
      session = insert(:chat_session, ingestion: ingestion)
      chunk = insert(:chunk, library: library, ingestion: ingestion)
      message = insert(:message, session: session)
      insert(:chat_source, chunk: chunk, message: message)

      assert %Message{} = result = Chats.get_message!(message.id)
      assert result.id == message.id
      assert_preloaded(result, :source_chunks)
    end
  end

  describe "start_session/1" do
    setup [:insert_user]

    test "errors with a changeset for invalid attrs", %{user: user} do
      assert {:error, changeset} = Chats.start_session(user, %{})
      assert_required_error_on(changeset, :ingestion_id)
      assert_required_error_on(changeset, :prompt)
    end

    test "creates a session, a message", %{user: user} do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)

      assert_count_differences(Repo, [{Session, 1}, {Message, 2}], fn ->
        assert {:ok, session} =
                 Chats.start_session(user, %{ingestion_id: ingestion.id, prompt: "Hello"})

        assert session.ingestion_id == ingestion.id
        assert session.title == "Hello"
        assert session.user_id == user.id

        # messages are sorted asc: :index on sessions
        [message, assistant_message] = session.messages
        assert message.index == 0
        assert message.role == :user
        assert message.content == "Hello"
        refute message.incomplete

        assert assistant_message.index == 1
        assert assistant_message.role == :assistant
        assert assistant_message.content == ""
        assert assistant_message.incomplete
        assert assistant_message.sources == []

        wait_for_generation_task()

        refute Repo.reload(assistant_message).incomplete
      end)
    end
  end

  describe "continue_session/1" do
    setup [:insert_user]

    setup %{user: user} do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)
      session = insert(:chat_session, user: user, ingestion: ingestion)
      insert(:message, session: session, index: 0, role: :user, content: "Hello")
      insert(:message, session: session, index: 1, role: :assistant, content: "Howdie!")

      %{session: session}
    end

    test "errors with a changeset for invalid attrs", %{session: session} do
      assert {:error, changeset} = Chats.continue_session(session, %{})
      assert_required_error_on(changeset, :index)
      assert_required_error_on(changeset, :content)
    end

    test "raises if the message index is already taken", %{session: session} do
      assert_raise Ecto.ConstraintError, fn ->
        Chats.continue_session(session, %{content: "foo", index: 1})
      end
    end

    test "creates a message", %{session: session} do
      assert_count_differences(Repo, [{Message, 2}], fn ->
        assert {:ok, [message, assistant_message]} =
                 Chats.continue_session(session, %{
                   index: 2,
                   content: "What's the recipe for cookies?"
                 })

        assert message.index == 2
        assert message.role == :user
        assert message.content == "What's the recipe for cookies?"
        refute message.incomplete

        assert assistant_message.index == 3
        assert assistant_message.role == :assistant
        assert assistant_message.content == ""
        assert assistant_message.incomplete
        assert assistant_message.sources == []

        wait_for_generation_task()

        refute Repo.reload(assistant_message).incomplete
      end)
    end
  end

  describe "delete_session/1" do
    test "deletes the session" do
      session = insert(:chat_session)
      assert {:ok, _} = Chats.delete_session(session)
    end
  end

  describe "upsert_reaction!/3" do
    setup [:insert_user]

    test "creates new reaction for message and user", %{user: user} do
      ingestion = insert(:ingestion)
      session = insert(:chat_session, user: user, ingestion: ingestion)
      message = insert(:message, session: session)
      _other_message = insert(:message, session: session)

      # Some other records
      other_session = insert(:chat_session, user: user, ingestion: ingestion)
      _other_message = insert(:message, session: other_session)

      reaction =
        assert_count_differences(Repo, [{Reaction, 1}], fn ->
          assert %Reaction{} = reaction = Chats.upsert_reaction!(message.id, session, :upvote)
          assert reaction.message_id == message.id
          assert reaction.ingestion_id == ingestion.id
          assert reaction.user_id == user.id
          assert reaction.type == :upvote
          reaction
        end)

      # Now upsert the vote -> no new reaction is created
      assert_count_differences(Repo, [{Reaction, 0}], fn ->
        assert %Reaction{} = Chats.upsert_reaction!(message.id, session, :downvote)
      end)

      assert Repo.reload(reaction).type == :downvote
    end
  end

  describe "delete_reaction/1 when the reaction does not exist" do
    test "returns an error" do
      assert Chats.delete_reaction(uuid()) == {:error, {:not_found, Reaction}}
    end
  end

  describe "delete_reaction/1" do
    test "deletes the reaction" do
      reaction = insert(:reaction)
      assert {:ok, _} = Chats.delete_reaction(reaction.id)
      refute Repo.reload(reaction)
    end
  end
end
