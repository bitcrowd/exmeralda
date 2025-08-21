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

  describe "get_session/2 when the session does not exist" do
    test "raises an error" do
      assert_raise Ecto.NoResultsError, fn -> Chats.get_session!(uuid(), uuid()) end
    end
  end

  describe "get_session/2 when the session does not belong to the user" do
    test "raises an error" do
      session = insert(:chat_session)
      assert_raise Ecto.NoResultsError, fn -> Chats.get_session!(uuid(), session.id) end
    end
  end

  describe "get_session/2 when the session's user was nilified" do
    setup [:insert_user]

    test "returns an error", %{user: user} do
      session = insert(:chat_session, user_id: nil)
      assert_raise Ecto.NoResultsError, fn -> Chats.get_session!(user.id, session.id) end
    end
  end

  describe "get_session!/2" do
    setup [:insert_user]

    setup %{user: user} do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)
      session = insert(:chat_session, user: user, ingestion: ingestion)
      message = insert(:message, session: session)
      chunk = insert(:chunk, library: library, ingestion: ingestion)
      insert(:chat_source, chunk: chunk, message: message)
      insert(:reaction, message: message)

      %{session: session, message: message, library: library}
    end

    test "returns the session by user and session ID and preloads library, messages, message chunks and reaction",
         %{
           session: %{id: session_id},
           user: user,
           library: library,
           message: %{id: message_id}
         } do
      assert %Session{} = session = Chats.get_session!(user.id, session_id)
      assert session.id == session_id
      assert session.user_id == user.id
      assert_preloaded(session, :library)
      assert_preloaded(session, :messages)

      assert session.library.id == library.id
      assert [%{id: ^message_id} = message] = session.messages
      assert_preloaded(message, :source_chunks)
      assert_preloaded(message, :reaction)
    end
  end

  describe "list_sessions_for_ingestion/1" do
    test "returns the chat sessions of an ingestion" do
      ingestion = insert(:ingestion)
      %{id: session_id} = insert(:chat_session, ingestion: ingestion)
      insert(:chat_session)

      assert [%Session{id: ^session_id}] = Chats.list_sessions_for_ingestion(ingestion.id)
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
      chunk = insert(:chunk, ingestion: ingestion)
      message = insert(:message, session: session)
      insert(:chat_source, chunk: chunk, message: message)

      assert %Message{} = result = Chats.get_message!(message.id)
      assert result.id == message.id
      assert_preloaded(result, :source_chunks)
    end
  end

  describe "start_session/2" do
    setup [:insert_user]

    test "errors with a changeset for invalid attrs", %{user: user} do
      assert {:error, changeset} = Chats.start_session(user, %{"ingestion_id" => uuid()})
      assert_required_error_on(changeset, :prompt)
    end

    test "errors with a changeset when the ingestion does not exist", %{user: user} do
      assert {:error, changeset} =
               Chats.start_session(user, %{
                 "library_id" => uuid(),
                 "ingestion_id" => uuid(),
                 "prompt" => "hello"
               })

      assert_foreign_key_constraint_on(changeset, :ingestion_id)
    end

    test "creates a session, a message", %{user: user} do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)

      assert_count_differences(Repo, [{Session, 1}, {Message, 2}], fn ->
        assert {:ok, session} =
                 Chats.start_session(user, %{
                   "ingestion_id" => ingestion.id,
                   "library_id" => library.id,
                   "prompt" => "Hello"
                 })

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

  describe "unlink_user_from_session/2 when the session does not exist" do
    test "returns an error" do
      assert Chats.unlink_user_from_session(uuid(), uuid()) == {:error, {:not_found, Session}}
    end
  end

  describe "unlink_user_from_session/2 when the session does belong to the user" do
    test "returns an error" do
      user = insert(:user)
      session = insert(:chat_session, user: user)
      assert Chats.unlink_user_from_session(uuid(), session.id) == {:error, {:not_found, Session}}
      assert Repo.reload(session).user_id
    end
  end

  describe "unlink_user_from_session/2" do
    test "unsets used_id on the session" do
      user = insert(:user)
      session = insert(:chat_session, user: user)
      assert {:ok, updated_session} = Chats.unlink_user_from_session(user.id, session.id)
      refute updated_session.user_id
    end
  end

  describe "upsert_reaction/2 when the message is not found" do
    test "returns an error" do
      assert Chats.upsert_reaction(uuid(), :upvote) == {:error, {:not_found, Message}}
    end
  end

  describe "upsert_reaction/2 when the message is not from the assistant" do
    test "returns an error" do
      session = insert(:chat_session)
      message = insert(:message, session: session, role: :user)

      assert Chats.upsert_reaction(message.id, :upvote) == {:error, :message_not_from_assistant}
    end
  end

  describe "upsert_reaction/2" do
    setup [:insert_user]

    test "creates new reaction for message", %{user: user} do
      ingestion = insert(:ingestion)
      session = insert(:chat_session, user: user, ingestion: ingestion)
      message = insert(:message, session: session, role: :assistant)
      _other_message = insert(:message, session: session)

      # Some other records
      other_session = insert(:chat_session, user: user, ingestion: ingestion)
      _other_message = insert(:message, session: other_session)

      reaction =
        assert_count_differences(Repo, [{Reaction, 1}], fn ->
          assert {:ok, %Message{} = updated_message} = Chats.upsert_reaction(message.id, :upvote)

          assert_preloaded(updated_message, [:reaction])

          reaction = updated_message.reaction
          assert reaction.message_id == message.id
          assert reaction.type == :upvote
          reaction
        end)

      # Now upsert the vote -> no new reaction is created
      assert_count_differences(Repo, [{Reaction, 0}], fn ->
        assert {:ok, %Message{} = updated_message} = Chats.upsert_reaction(message.id, :downvote)

        assert updated_message.reaction.type == :downvote
      end)

      assert Repo.reload(reaction).type == :downvote
    end
  end

  describe "delete_reaction/1 when the reaction does not exist" do
    test "returns ok" do
      assert Chats.delete_reaction(uuid()) == :ok
    end
  end

  describe "delete_reaction/1" do
    test "deletes the reaction" do
      reaction = insert(:reaction)
      assert Chats.delete_reaction(reaction.id) == :ok
      refute Repo.reload(reaction)
    end
  end

  describe "count_reactions_for_ingestions/1" do
    test "count number of reaction per type for given ingestions" do
      ingestion = insert(:ingestion)

      for _n <- 1..3 do
        session = insert(:chat_session, ingestion: ingestion)
        insert(:reaction, type: :upvote, message: insert(:message, session: session))
      end

      session = insert(:chat_session, ingestion: ingestion)

      for _n <- 1..2 do
        insert(:reaction, type: :downvote, message: insert(:message, session: session))
      end

      # Other ingestion data
      other_ingestion = insert(:ingestion)
      other_session = insert(:chat_session, ingestion: other_ingestion)
      insert(:reaction, type: :downvote, message: insert(:message, session: other_session))

      ingestion_id = ingestion.id
      other_ingestion_id = other_ingestion.id

      assert %{
               ^ingestion_id => [{:downvote, 2}, {:upvote, 3}],
               ^other_ingestion_id => [downvote: 1]
             } =
               Chats.count_reactions_for_ingestions([ingestion.id, other_ingestion.id])
    end
  end
end
