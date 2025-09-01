defmodule Exmeralda.ChatsTest do
  use Exmeralda.DataCase, async: false

  alias Exmeralda.Chats
  alias Exmeralda.Chats.{Message, Session, Reaction, GenerationEnvironment, Source}
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

    setup do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)
      provider = insert(:provider, type: :mock)
      model_config = insert(:model_config)

      model_config_provider =
        insert(:model_config_provider,
          model_config: model_config,
          provider: provider,
          id: test_model_config_provider_id()
        )

      system_prompt = insert(:system_prompt, id: test_system_prompt_id())
      generation_prompt = insert(:generation_prompt, id: test_generation_prompt_id())

      %{
        library: library,
        ingestion: ingestion,
        model_config_provider: model_config_provider,
        system_prompt: system_prompt,
        generation_prompt: generation_prompt
      }
    end

    test "errors with a changeset with invalid attrs", %{user: user} do
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

    test "raises if the current model config provider does not exist", %{
      user: user,
      library: library,
      ingestion: ingestion,
      model_config_provider: model_config_provider
    } do
      Repo.delete(model_config_provider)

      assert_raise RuntimeError, ~r/Could not find the current LLM model config provider!/, fn ->
        Chats.start_session(user, %{
          "ingestion_id" => ingestion.id,
          "library_id" => library.id,
          "prompt" => "Hello"
        })
      end
    end

    test "creates a session, a message and a upserts generation environment", %{
      user: user,
      library: library,
      ingestion: ingestion,
      model_config_provider: model_config_provider,
      system_prompt: system_prompt,
      generation_prompt: generation_prompt
    } do
      generation_environment =
        assert_count_differences(
          Repo,
          [{Session, 1}, {Message, 2}, {GenerationEnvironment, 1}],
          fn ->
            assert {:ok, session} =
                     Chats.start_session(user, %{
                       "ingestion_id" => ingestion.id,
                       "library_id" => library.id,
                       "prompt" => "Hello"
                     })

            assert session.ingestion_id == ingestion.id
            assert session.title == "Hello"
            assert session.user_id == user.id

            [generation_environment] = Repo.all(GenerationEnvironment)
            assert generation_environment.model_config_provider_id == model_config_provider.id
            assert generation_environment.system_prompt_id == system_prompt.id
            assert generation_environment.generation_prompt_id == generation_prompt.id

            # messages are sorted asc: :index on sessions
            [message, assistant_message] = session.messages
            assert message.index == 0
            assert message.role == :user
            assert message.content == "Hello"
            refute message.incomplete
            assert message.generation_environment_id == generation_environment.id

            assert assistant_message.index == 1
            assert assistant_message.role == :assistant
            assert assistant_message.content == ""
            assert assistant_message.incomplete
            assert assistant_message.sources == []
            assert assistant_message.generation_environment_id == generation_environment.id

            wait_for_generation_task()

            refute Repo.reload(assistant_message).incomplete

            generation_environment
          end
        )

      # Starting a session with the same generation environment does not create a new one
      assert_count_differences(
        Repo,
        [{Session, 1}, {Message, 2}, {GenerationEnvironment, 0}],
        fn ->
          assert {:ok, session} =
                   Chats.start_session(user, %{
                     "ingestion_id" => ingestion.id,
                     "library_id" => library.id,
                     "prompt" => "Hello again"
                   })

          [message, assistant_message] = session.messages
          assert assistant_message.generation_environment_id == generation_environment.id
          assert message.generation_environment_id == generation_environment.id

          wait_for_generation_task()
        end
      )

      assert Repo.aggregate(GenerationEnvironment, :count) == 1
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

      provider = insert(:provider, type: :mock)
      model_config = insert(:model_config)

      model_config_provider =
        insert(:model_config_provider,
          model_config: model_config,
          provider: provider,
          id: test_model_config_provider_id()
        )

      system_prompt = insert(:system_prompt, id: test_system_prompt_id())
      generation_prompt = insert(:generation_prompt, id: test_generation_prompt_id())

      %{
        session: session,
        model_config_provider: model_config_provider,
        system_prompt: system_prompt,
        generation_prompt: generation_prompt
      }
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

    test "raises if the current model config provider does not exist", %{
      session: session,
      model_config_provider: model_config_provider
    } do
      Repo.delete(model_config_provider)

      assert_raise RuntimeError, ~r/Could not find the current LLM model config provider!/, fn ->
        Chats.continue_session(session, %{
          index: 2,
          content: "What's the recipe for cookies?"
        })
      end
    end

    test "creates a message and upserts a generation environment", %{
      session: session,
      model_config_provider: model_config_provider,
      system_prompt: system_prompt,
      generation_prompt: generation_prompt
    } do
      assert Repo.aggregate(GenerationEnvironment, :count) == 2

      generation_environment =
        assert_count_differences(Repo, [{Message, 2}, {GenerationEnvironment, 1}], fn ->
          assert {:ok, [message, assistant_message]} =
                   Chats.continue_session(session, %{
                     index: 2,
                     content: "What's the recipe for cookies?"
                   })

          generation_environment =
            Repo.get_by(GenerationEnvironment, model_config_provider_id: model_config_provider.id)

          assert generation_environment.model_config_provider_id == model_config_provider.id
          assert generation_environment.system_prompt_id == system_prompt.id
          assert generation_environment.generation_prompt_id == generation_prompt.id

          assert message.index == 2
          assert message.role == :user
          assert message.content == "What's the recipe for cookies?"
          refute message.incomplete
          assert message.generation_environment_id == generation_environment.id

          assert assistant_message.index == 3
          assert assistant_message.role == :assistant
          assert assistant_message.content == ""
          assert assistant_message.incomplete
          assert assistant_message.sources == []
          assert assistant_message.generation_environment_id == generation_environment.id

          wait_for_generation_task()

          refute Repo.reload(assistant_message).incomplete
          generation_environment
        end)

      # Continuing with the same model config does not create a new generation environment
      assert_count_differences(Repo, [{Message, 2}, {GenerationEnvironment, 0}], fn ->
        assert {:ok, [message, assistant_message]} =
                 Chats.continue_session(session, %{
                   index: 4,
                   content: "What's the recipe for cookies again?"
                 })

        assert message.generation_environment_id == generation_environment.id
        assert assistant_message.generation_environment_id == generation_environment.id

        wait_for_generation_task()
      end)

      assert Repo.aggregate(GenerationEnvironment, :count) == 3
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
               ^ingestion_id => votes,
               ^other_ingestion_id => [downvote: 1]
             } =
               Chats.count_reactions_for_ingestions([ingestion.id, other_ingestion.id])

      assert Keyword.fetch!(votes, :downvote) == 2
      assert Keyword.fetch!(votes, :upvote) == 3
    end
  end

  describe "regenerate/2 when the message does not exist" do
    test "returns an error" do
      assert Chats.regenerate(uuid(), uuid()) == {:error, {:not_found, Message}}
    end
  end

  describe "regenerate/2 when the generation environment does not exist" do
    test "returns an error" do
      message = insert(:message)
      assert Chats.regenerate(message.id, uuid()) == {:error, {:not_found, GenerationEnvironment}}
    end
  end

  describe "regenerate/2 when the message is from the assistant" do
    test "returns an error" do
      message = insert(:message, role: :assistant)

      assert Chats.regenerate(message.id, uuid()) ==
               {:error, {:message_not_from_user, "message \"#{message.id}\" has role: :assitant"}}
    end
  end

  describe "regenerate/2" do
    setup do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)
      user = insert(:user)
      other_generation_environment = insert(:generation_environment)
      session = insert(:chat_session, user: user, ingestion: ingestion)
      chunk = insert(:chunk, library: library, ingestion: ingestion)
      other_chunk = insert(:chunk, library: library, ingestion: ingestion)

      # Messages
      initial_message =
        insert(:message,
          session: session,
          index: 0,
          role: :user,
          content: "Hello",
          generation_environment: other_generation_environment
        )

      assistant_message =
        insert(:message,
          session: session,
          index: 1,
          role: :assistant,
          content: "Howdie!",
          generation_environment: other_generation_environment
        )

      insert(:chat_source, chunk: chunk, message: assistant_message)
      insert(:chat_source, chunk: other_chunk, message: assistant_message)

      message =
        insert(:message,
          session: session,
          index: 2,
          role: :user,
          content: "Where's the cookie jar?",
          generation_environment: other_generation_environment
        )

      insert(:message,
        session: session,
        index: 3,
        role: :assistant,
        content: "I ate all of the cookies...",
        generation_environment: other_generation_environment
      )

      # Reactions (not copied)
      insert(:reaction, message: assistant_message)

      provider = insert(:provider, type: :mock)
      model_config = insert(:model_config)

      model_config_provider =
        insert(:model_config_provider,
          model_config: model_config,
          provider: provider,
          id: test_model_config_provider_id()
        )

      system_prompt = insert(:system_prompt, id: test_system_prompt_id())
      generation_prompt = insert(:generation_prompt, id: test_generation_prompt_id())

      generation_environment =
        insert(:generation_environment,
          model_config_provider: model_config_provider,
          system_prompt: system_prompt,
          generation_prompt: generation_prompt
        )

      %{
        session: session,
        message: message,
        ingestion: ingestion,
        generation_environment: generation_environment,
        other_generation_environment: other_generation_environment,
        initial_message: initial_message,
        chunk: chunk,
        other_chunk: other_chunk
      }
    end

    test "duplicates the session and its messages, generates a new answer", %{
      session: session,
      message: message,
      ingestion: ingestion,
      generation_environment: generation_environment,
      other_generation_environment: other_generation_environment,
      chunk: chunk,
      other_chunk: other_chunk
    } do
      assert_count_differences(
        Repo,
        [{Session, 1}, {Message, 4}, {GenerationEnvironment, 0}, {Reaction, 0}, {Source, 4}],
        fn ->
          assert {:ok, duplicated_session_id} =
                   Chats.regenerate(message.id, generation_environment.id)

          wait_for_generation_task()

          duplicated_session = Repo.get!(Session, duplicated_session_id)
          assert duplicated_session.original_session_id == session.id
          assert duplicated_session.copied_from_message_id == message.id
          assert duplicated_session.title == session.title
          assert duplicated_session.ingestion_id == ingestion.id

          %{messages: [first_message, second_message, third_message, fourth_message]} =
            Repo.preload(duplicated_session, messages: [:sources])

          # Copied message 0
          assert %{index: 0, role: :user, content: "Hello", incomplete: false, sources: []} =
                   first_message

          assert first_message.generation_environment_id == other_generation_environment.id

          # Copied message 1
          assert %{index: 1, role: :assistant, content: "Howdie!", incomplete: false} =
                   second_message

          assert second_message.generation_environment_id == other_generation_environment.id

          assert_sorted_equal(Enum.map(second_message.sources, & &1.chunk_id), [
            chunk.id,
            other_chunk.id
          ])

          # Copied message 2 -> The message we want to start from has the new generation environment set
          assert %{
                   index: 2,
                   role: :user,
                   content: "Where's the cookie jar?",
                   incomplete: false,
                   sources: []
                 } =
                   third_message

          assert third_message.generation_environment_id == generation_environment.id

          # Regenerated message
          assert %{
                   index: 3,
                   role: :assistant,
                   content: "This is a streaming response!",
                   incomplete: false
                 } = fourth_message

          assert fourth_message.generation_environment_id == generation_environment.id
          assert length(fourth_message.sources) == 2
        end
      )
    end

    test "works if we start from another message", %{
      session: session,
      initial_message: initial_message,
      ingestion: ingestion,
      generation_environment: generation_environment
    } do
      assert_count_differences(
        Repo,
        [{Session, 1}, {Message, 2}, {GenerationEnvironment, 0}, {Reaction, 0}, {Source, 2}],
        fn ->
          assert {:ok, duplicated_session_id} =
                   Chats.regenerate(initial_message.id, generation_environment.id)

          wait_for_generation_task()

          duplicated_session = Repo.get!(Session, duplicated_session_id)
          assert duplicated_session.original_session_id == session.id
          assert duplicated_session.copied_from_message_id == initial_message.id
          assert duplicated_session.title == session.title
          assert duplicated_session.ingestion_id == ingestion.id

          %{messages: [first_message, second_message]} =
            Repo.preload(duplicated_session, messages: [:sources])

          # Copied message 0
          assert %{index: 0, role: :user, content: "Hello", incomplete: false, sources: []} =
                   first_message

          assert first_message.generation_environment_id == generation_environment.id

          # Regenerated message
          assert %{
                   index: 1,
                   role: :assistant,
                   content: "This is a streaming response!",
                   incomplete: false
                 } = second_message

          assert second_message.generation_environment_id == generation_environment.id
          assert length(second_message.sources) == 2
        end
      )
    end
  end
end
