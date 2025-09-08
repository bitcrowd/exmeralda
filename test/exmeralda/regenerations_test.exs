defmodule Exmeralda.RegenerationsTest do
  use Exmeralda.DataCase, async: false
  alias Exmeralda.Regenerations
  alias Exmeralda.Chats.{Message, Session, Reaction, GenerationEnvironment, Source}
  alias Exmeralda.Repo

  describe "regenerate_messages/2 when the message does not exist" do
    test "returns an error" do
      message_id = uuid()

      assert Regenerations.regenerate_messages([message_id], uuid()) == %{
               message_id => {:not_found, Message}
             }
    end
  end

  describe "regenerate_messages/2 when the generation environment does not exist" do
    test "returns an error" do
      %{id: message_id} = insert(:message, role: :assistant)

      assert Regenerations.regenerate_messages([message_id], uuid()) == %{
               message_id => {:not_found, GenerationEnvironment}
             }
    end
  end

  describe "regenerate_messages/2 when the message is from the user" do
    test "returns an error" do
      %{id: message_id} = insert(:message, role: :user)
      generation_environment = insert(:generation_environment)

      assert Regenerations.regenerate_messages([message_id], generation_environment.id) == %{
               message_id =>
                 {:message_not_from_assistant, "message \"#{message_id}\" has role: :user"}
             }
    end
  end

  describe "regenerate_messages/2" do
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
          content: "Hello buttercup!",
          generation_environment: other_generation_environment
        )

      first_assistant_message =
        insert(:message,
          session: session,
          index: 1,
          role: :assistant,
          content: "Howdie!",
          generation_environment: other_generation_environment
        )

      insert(:chat_source, chunk: chunk, message: first_assistant_message)
      insert(:chat_source, chunk: other_chunk, message: first_assistant_message)

      insert(:message,
        session: session,
        index: 2,
        role: :user,
        content: "Where's the cookie jar?",
        generation_environment: other_generation_environment
      )

      second_assistant_message =
        insert(:message,
          session: session,
          index: 3,
          role: :assistant,
          content: "I ate all of the cookies...",
          generation_environment: other_generation_environment
        )

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
        first_assistant_message: first_assistant_message,
        second_assistant_message: second_assistant_message,
        ingestion: ingestion,
        generation_environment: generation_environment,
        other_generation_environment: other_generation_environment,
        initial_message: initial_message,
        chunk: chunk,
        other_chunk: other_chunk
      }
    end

    test "regenerates many messages", %{
      first_assistant_message: first_assistant_message,
      generation_environment: generation_environment
    } do
      first_assistant_message_id = first_assistant_message.id

      assert_count_differences(
        Repo,
        [{Session, 1}, {Message, 2}, {GenerationEnvironment, 0}, {Reaction, 0}, {Source, 2}],
        fn ->
          assert %{
                   regenerated_messages: [
                     {^first_assistant_message_id, %{assistant_message_id: assitant_message_id}}
                   ],
                   skipped_messages: %{}
                 } =
                   Regenerations.regenerate_messages(
                     [first_assistant_message_id],
                     generation_environment.id
                   )

          wait_for_generation_task()

          regenerated_message = Repo.get(Message, assitant_message_id)
          assert regenerated_message.regenerated_from_message_id == first_assistant_message_id
          refute regenerated_message.incomplete
          assert regenerated_message.role == :assistant
          assert regenerated_message.index == 1
          assert regenerated_message.generation_environment_id == generation_environment.id
        end
      )
    end

    test "handles missing messages", %{
      first_assistant_message: first_assistant_message,
      generation_environment: generation_environment
    } do
      first_assistant_message_id = first_assistant_message.id
      message_id = uuid()

      assert_count_differences(
        Repo,
        [{Session, 1}, {Message, 2}, {GenerationEnvironment, 0}, {Reaction, 0}, {Source, 2}],
        fn ->
          assert %{
                   regenerated_messages: [
                     {^first_assistant_message_id, %{assistant_message_id: assitant_message_id}}
                   ],
                   skipped_messages: %{
                     ^message_id => {:not_found, Message}
                   }
                 } =
                   Regenerations.regenerate_messages(
                     [first_assistant_message_id, message_id],
                     generation_environment.id
                   )

          wait_for_generation_task()

          regenerated_message = Repo.get(Message, assitant_message_id)
          assert regenerated_message.regenerated_from_message_id == first_assistant_message_id
          refute regenerated_message.incomplete
          assert regenerated_message.role == :assistant
          assert regenerated_message.index == 1
          assert regenerated_message.generation_environment_id == generation_environment.id
        end
      )
    end

    @tag :tmp_dir
    test "saves to a json file optionally", %{
      first_assistant_message: first_assistant_message,
      initial_message: initial_message,
      generation_environment: generation_environment,
      tmp_dir: tmp_dir
    } do
      first_assistant_message_id = first_assistant_message.id

      assert_count_differences(
        Repo,
        [{Session, 1}, {Message, 2}, {GenerationEnvironment, 0}, {Reaction, 0}, {Source, 2}],
        fn ->
          assert {:ok, filepath} =
                   Regenerations.regenerate_messages(
                     [first_assistant_message_id],
                     generation_environment.id,
                     download: true,
                     download_path: tmp_dir
                   )

          assert String.ends_with?(filepath, ".json")
          wait_for_generation_task()
          result = File.read!(filepath) |> Jason.decode!()

          assert [
                   %{
                     "generation" => %{
                       "assistant_response" => "This is a streaming response!",
                       "chunks" => [
                         %{
                           "content" => "I am a message",
                           "source" => "file.ex"
                         },
                         %{
                           "content" => "I am a message",
                           "source" => "file.ex"
                         }
                       ],
                       "full_user_prompt" =>
                         "Context information is below.\n---------------------\nI am a message\n\nI am a message\n---------------------\nGiven the context information and no prior knowledge, answer the query.\nQuery: Hello buttercup!\nAnswer:\n",
                       "user_message_id" => user_message_id,
                       "assistant_message_id" => assistant_message_id,
                       "user_query" => "Hello buttercup!"
                     },
                     "generation_environment" => %{
                       "embedding_model" => "fake",
                       "embedding_provider" => "mock",
                       "embedding_provider_config" => %{},
                       "model_name" => "fake-model",
                       "model_provider" => "mock",
                       "model_provider_config" => %{"model" => "Fake/Fake-model"},
                       "prompt_template" =>
                         "Context information is below.\n---------------------\n%{context}\n---------------------\nGiven the context information and no prior knowledge, answer the query.\nQuery: %{query}\nAnswer:\n",
                       "system_prompt" =>
                         "You are an expert in Elixir programming with in-depth knowledge of Elixir."
                     }
                   }
                 ] = result

          # Duplicated initial user message
          user_message = Repo.get(Message, user_message_id)
          assert user_message.index == 0
          assert user_message.content == "Hello buttercup!"
          assert user_message.generation_environment_id == generation_environment.id
          refute initial_message.id == user_message.id

          duplicated_session =
            Repo.get(Session, user_message.session_id) |> Repo.preload([:messages])

          # Regenerated assistant message
          [_, assistant_message] = duplicated_session.messages
          assert assistant_message.id == assistant_message_id
        end
      )
    end
  end

  describe "download/2" do
    setup do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)
      user = insert(:user)
      session = insert(:chat_session, user: user, ingestion: ingestion)
      chunk = insert(:chunk, library: library, ingestion: ingestion)
      other_generation_environment = insert(:generation_environment)
      generation_environment = insert(:generation_environment)

      # Messages
      first_assistant_message =
        insert(:message,
          session: session,
          index: 1,
          role: :assistant,
          content: "Howdie!",
          generation_environment: other_generation_environment
        )

      duplicated_session = insert(:chat_session, user: nil, ingestion: ingestion)

      duplicated_message =
        insert(:message,
          session: duplicated_session,
          index: 0,
          role: :user,
          content: "Hello buttercup!",
          generation_environment: generation_environment
        )

      regenerated_assistant_message =
        insert(:message,
          session: duplicated_session,
          index: 1,
          role: :assistant,
          content: "I ate all of the cookies...",
          generation_environment: generation_environment,
          regenerated_from_message_id: first_assistant_message.id
        )

      insert(:chat_source, chunk: chunk, message: regenerated_assistant_message)

      %{
        regenerated_assistant_message: regenerated_assistant_message,
        duplicated_message: duplicated_message
      }
    end

    @tag :tmp_dir
    test "downloads a JSON", %{
      regenerated_assistant_message: %{id: assistant_message_id},
      duplicated_message: %{id: user_message_id},
      tmp_dir: tmp_dir
    } do
      assert_count_differences(
        Repo,
        [{Session, 0}, {Message, 0}, {GenerationEnvironment, 0}, {Reaction, 0}, {Source, 0}],
        fn ->
          assert {:ok, filepath} =
                   Regenerations.download([assistant_message_id], download_path: tmp_dir)

          assert String.ends_with?(filepath, ".json")
          result = File.read!(filepath) |> Jason.decode!()

          assert [
                   %{
                     "generation" => %{
                       "assistant_response" => "I ate all of the cookies...",
                       "chunks" => [
                         %{
                           "content" => "I am a message",
                           "source" => "file.ex"
                         }
                       ],
                       "full_user_prompt" =>
                         "Context information is below.\n---------------------\nI am a message\n---------------------\nGiven the context information and no prior knowledge, answer the query.\nQuery: Hello buttercup!\nAnswer:\n",
                       "user_message_id" => ^user_message_id,
                       "assistant_message_id" => ^assistant_message_id,
                       "user_query" => "Hello buttercup!"
                     },
                     "generation_environment" => %{
                       "embedding_model" => "fake",
                       "embedding_provider" => "mock",
                       "embedding_provider_config" => %{},
                       "model_name" => "fake-model",
                       "model_provider" => "mock",
                       "model_provider_config" => %{"model" => "Fake/Fake-model"},
                       "prompt_template" =>
                         "Context information is below.\n---------------------\n%{context}\n---------------------\nGiven the context information and no prior knowledge, answer the query.\nQuery: %{query}\nAnswer:\n",
                       "system_prompt" =>
                         "You are an expert in Elixir programming with in-depth knowledge of Elixir."
                     }
                   }
                 ] = result
        end
      )
    end
  end

  describe "regenerate/2 when the message does not exist" do
    test "returns an error" do
      assert Regenerations.regenerate(uuid(), uuid()) == {:error, {:not_found, Message}}
    end
  end

  describe "regenerate/2 when the message is from the user" do
    test "returns an error" do
      message = insert(:message, role: :user)

      assert Regenerations.regenerate(message.id, uuid()) ==
               {:error,
                {:message_not_from_assistant, "message \"#{message.id}\" has role: :user"}}
    end
  end

  describe "regenerate/2 when the generation environment does not exist" do
    test "returns an error" do
      message = insert(:message, role: :assistant)

      assert Regenerations.regenerate(message.id, uuid()) ==
               {:error, {:not_found, GenerationEnvironment}}
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
      insert(:message,
        session: session,
        index: 0,
        role: :user,
        content: "Hello",
        generation_environment: other_generation_environment
      )

      first_assistant_message =
        insert(:message,
          session: session,
          index: 1,
          role: :assistant,
          content: "Howdie!",
          generation_environment: other_generation_environment
        )

      insert(:chat_source, chunk: chunk, message: first_assistant_message)
      insert(:chat_source, chunk: other_chunk, message: first_assistant_message)

      second_user_message =
        insert(:message,
          session: session,
          index: 2,
          role: :user,
          content: "Where's the cookie jar?",
          generation_environment: other_generation_environment
        )

      second_assistant_message =
        insert(:message,
          session: session,
          index: 3,
          role: :assistant,
          content: "I ate all of the cookies...",
          generation_environment: other_generation_environment
        )

      # Reactions (not copied)
      insert(:reaction, message: first_assistant_message)

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
        first_assistant_message: first_assistant_message,
        second_assistant_message: second_assistant_message,
        second_user_message: second_user_message,
        ingestion: ingestion,
        generation_environment: generation_environment,
        other_generation_environment: other_generation_environment,
        chunk: chunk,
        other_chunk: other_chunk
      }
    end

    test "duplicates the session and its messages, generates a new answer", %{
      session: session,
      second_assistant_message: second_assistant_message,
      second_user_message: second_user_message,
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
          assert {:ok,
                  %{
                    session_id: duplicated_session_id,
                    user_message: user_message,
                    assistant_message: assistant_message,
                    generation_environment: returned_generation_environment
                  }} =
                   Regenerations.regenerate(
                     second_assistant_message.id,
                     generation_environment.id
                   )

          wait_for_generation_task()

          duplicated_session = Repo.get!(Session, duplicated_session_id)
          assert duplicated_session.original_session_id == session.id
          assert duplicated_session.copied_from_message_id == second_assistant_message.id
          assert duplicated_session.title == session.title
          assert duplicated_session.ingestion_id == ingestion.id
          refute duplicated_session.user_id

          assert second_user_message.content == user_message.content
          assert returned_generation_environment.id == generation_environment.id

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

          # Copied message 2 -> The user message we want regenerate an answer for has the new generation environment set
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
          assert fourth_message.id == assistant_message.id
        end
      )
    end

    test "works if we start from another message", %{
      session: session,
      first_assistant_message: first_assistant_message,
      ingestion: ingestion,
      generation_environment: generation_environment
    } do
      assert_count_differences(
        Repo,
        [{Session, 1}, {Message, 2}, {GenerationEnvironment, 0}, {Reaction, 0}, {Source, 2}],
        fn ->
          assert {:ok, %{session_id: duplicated_session_id}} =
                   Regenerations.regenerate(first_assistant_message.id, generation_environment.id)

          wait_for_generation_task()

          duplicated_session = Repo.get!(Session, duplicated_session_id)
          assert duplicated_session.original_session_id == session.id
          assert duplicated_session.copied_from_message_id == first_assistant_message.id
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
          assert second_message.regenerated_from_message_id == first_assistant_message.id
        end
      )
    end
  end

  describe "regenerate/2 when past messages are missing a generation environment" do
    setup do
      library = insert(:library)
      ingestion = insert(:ingestion, library: library)
      user = insert(:user)
      other_generation_environment = insert(:generation_environment)
      session = insert(:chat_session, user: user, ingestion: ingestion)
      chunk = insert(:chunk, library: library, ingestion: ingestion)
      other_chunk = insert(:chunk, library: library, ingestion: ingestion)

      # Messages
      insert(:message,
        session: session,
        index: 0,
        role: :user,
        content: "Hello",
        generation_environment: nil
      )

      first_assistant_message =
        insert(:message,
          session: session,
          index: 1,
          role: :assistant,
          content: "Howdie!",
          generation_environment: nil
        )

      insert(:chat_source, chunk: chunk, message: first_assistant_message)
      insert(:chat_source, chunk: other_chunk, message: first_assistant_message)

      insert(:message,
        session: session,
        index: 2,
        role: :user,
        content: "Where's the cookie jar?",
        generation_environment: other_generation_environment
      )

      second_assistant_message =
        insert(:message,
          session: session,
          index: 3,
          role: :assistant,
          content: "I ate all of the cookies...",
          generation_environment: other_generation_environment
        )

      # Reactions (not copied)
      insert(:reaction, message: first_assistant_message)

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
        first_assistant_message: first_assistant_message,
        second_assistant_message: second_assistant_message,
        ingestion: ingestion,
        generation_environment: generation_environment,
        other_generation_environment: other_generation_environment,
        chunk: chunk,
        other_chunk: other_chunk
      }
    end

    test "still works", %{
      session: session,
      second_assistant_message: second_assistant_message,
      ingestion: ingestion,
      generation_environment: generation_environment,
      chunk: chunk,
      other_chunk: other_chunk
    } do
      assert_count_differences(
        Repo,
        [{Session, 1}, {Message, 4}, {GenerationEnvironment, 0}, {Reaction, 0}, {Source, 4}],
        fn ->
          assert {:ok, %{session_id: duplicated_session_id}} =
                   Regenerations.regenerate(
                     second_assistant_message.id,
                     generation_environment.id
                   )

          wait_for_generation_task()

          duplicated_session = Repo.get!(Session, duplicated_session_id)
          assert duplicated_session.original_session_id == session.id
          assert duplicated_session.copied_from_message_id == second_assistant_message.id
          assert duplicated_session.title == session.title
          assert duplicated_session.ingestion_id == ingestion.id

          %{messages: [first_message, second_message, third_message, fourth_message]} =
            Repo.preload(duplicated_session, messages: [:sources])

          # Copied message 0
          assert %{index: 0, role: :user, content: "Hello", incomplete: false, sources: []} =
                   first_message

          refute first_message.generation_environment_id

          # Copied message 1
          assert %{index: 1, role: :assistant, content: "Howdie!", incomplete: false} =
                   second_message

          refute second_message.generation_environment_id

          assert_sorted_equal(Enum.map(second_message.sources, & &1.chunk_id), [
            chunk.id,
            other_chunk.id
          ])

          # Copied message 2 -> The message we want to regenerate an answer from has the new generation environment set
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
  end
end
