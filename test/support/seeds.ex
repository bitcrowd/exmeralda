defmodule Exmeralda.Seeds do
  alias Exmeralda.Repo
  alias Exmeralda.Topics.{Library, Ingestion, Chunk, Dependency}
  require Logger

  @library_fixture_path "priv/repo/fixtures/library_fixture.json"

  @default_system_prompt """
    You are an expert in Elixir programming with in-depth knowledge of Elixir.
    Provide accurate information based on the provided context to assist Elixir
    developers. Include code snippets and examples to illustrate your points.
    Respond in a professional yet approachable manner.
    Be concise for straightforward queries, but elaborate when necessary to
    ensure clarity and understanding. Adapt your responses to the complexity of
    the question. For basic usage, provide clear examples. For advanced topics,
    offer detailed explanations and multiple solutions if applicable.
    Include references to official documentation or reliable sources to support
    your answers. Ensure information is current, reflecting the latest updates
    in the library. If the context does not provide enough information, state
    this in your answer and keep it short. If you are unsure what kind of
    information the user needs, please ask follow-up questions.
  """

  @default_generation_prompt """
  Context information is below.
  ---------------------
  %{context}
  ---------------------
  Given the context information and no prior knowledge, answer the query.
  Query: %{query}
  Answer:
  """

  @rag_evaluation_system_prompt """
  You are an experienced Elixir library author. For the FAQ of your library, you need questions
  users could have. For each piece of markdown, come up with a question that is answered by
  the piece of markdown.

  """

  @rag_judge_system_prompt """
  You are an LLM judge. Follow the instructions in the user message exactly.
  Output only the JSON object requested. No prose, no markdown fences.
  """

  @rag_judge_generation_prompt """
  You are an LLM judge that is evaluating pairs of answers in terms of truthfulness and relevance, on a scale from 0.0 to 1.0.

  Given the following user query:
  ======= begin query =======
  %{query}
  ======= end query =======

  and the retrieved context:
  ======= begin context =======
  %{context}
  ======= end context =======

  here are the two answers:
  ======= begin first answer =======
  %{first_answer}
  ======= end first answer =======

  ======= begin second answer =======
  %{second_answer}
  ======= end second answer =======

  The scale for truthfulness is:
  - 0.0 not truthful at all
  - 1.0 fully truthful

  The scale for relevance is:
  - 0.0 not relevant at all
  - 1.0 completely relevant

  Which of the two answers would you choose? Give reasons for your answer.

  Output a single JSON object with exactly this shape:

  {
    "first_answer": {
      "relevance": 0.5,
      "truthfulness": 0.0
    },
    "second_answer": {
      "relevance": 0.5,
      "truthfulness": 0.0
    },
    "choice": {
      "answer": "first_answer",
      "reason": "The reason behind my choice..."
    }
  }

  The `choice.answer` field must be either "first_answer" or "second_answer".
  Output only the JSON object. No prose, no markdown fences.
  """

  def run do
    if Mix.env() == :dev do
      system_prompt =
        insert_idempotently(%Exmeralda.LLM.SystemPrompt{
          id: "c49195b4-daca-42af-835d-bdb928986d5c",
          prompt: @default_system_prompt
        })

      Exmeralda.LLM.SystemPrompts.activate_system_prompt(system_prompt.id)

      generation_prompt =
        insert_idempotently(%Exmeralda.Topics.GenerationPrompt{
          id: "3ef5b20b-bb71-467d-8364-898df9926a95",
          prompt: @default_generation_prompt
        })

      rag_evaluation_system_prompt =
        insert_idempotently(%Exmeralda.LLM.SystemPrompt{
          id: "3c792450-d57c-449b-a996-54101c41aede",
          prompt: @rag_evaluation_system_prompt
        })

      mock_provider =
        insert_idempotently(%Exmeralda.LLM.Provider{
          id: "62b47ee3-17ec-4c41-ac5e-3d8d6c0ac83d",
          type: :mock,
          name: "mock",
          config: %{}
        })

      mock_model_config =
        insert_idempotently(%Exmeralda.LLM.ModelConfig{
          id: "8270fc8e-d0df-4af1-9ddf-b208f5a8059e",
          name: "llm-fake-model",
          config: %{stream: true}
        })

      insert_idempotently(%Exmeralda.LLM.ModelConfigProvider{
        id: "1bf8d6a1-9c25-4f02-8c1b-767ebf11e37b",
        model_config_id: mock_model_config.id,
        provider_id: mock_provider.id,
        name: "Fake/Fake-model"
      })

      ollama_host = System.get_env("OLLAMA_HOST", "http://localhost:11434")

      ollama_provider =
        insert_idempotently(%Exmeralda.LLM.Provider{
          id: "1d7c3ee6-d189-4c85-ad59-116f92fdafd0",
          type: :ollama,
          name: "ollama_ai",
          config: %{"endpoint" => "#{ollama_host}/api/chat"}
        })

      ollama_model_config =
        insert_idempotently(%Exmeralda.LLM.ModelConfig{
          id: "7420d870-b10b-46ba-b30b-5c4630ee3a99",
          name: "llama3.2:latest",
          config: %{stream: true}
        })

      insert_idempotently(%Exmeralda.LLM.ModelConfigProvider{
        id: "1f0e49ff-a985-4c03-a89b-fa443842fa95",
        model_config_id: ollama_model_config.id,
        provider_id: ollama_provider.id,
        name: "llama3.2:latest"
      })

      together_provider =
        insert_idempotently(%Exmeralda.LLM.Provider{
          id: "684b2566-3cce-4711-963a-f646eb398388",
          type: :openai,
          name: "together_ai",
          config: %{endpoint: "https://api.together.xyz/v1/chat/completions"}
        })

      qwen_25_7b_model_config =
        insert_idempotently(%Exmeralda.LLM.ModelConfig{
          id: "eff70662-1576-491d-a1ef-1d025772e637",
          name: "qwen25-7b-instruct-turbo",
          config: %{stream: true}
        })

      gpt_oss_model_config =
        insert_idempotently(%Exmeralda.LLM.ModelConfig{
          id: "eff70662-1576-491d-a1ef-1d025772e637",
          name: "gpt-oss:latest",
          config: %{stream: true, json: true}
        })

      insert_idempotently(%Exmeralda.LLM.ModelConfigProvider{
        id: "073a0faf-024b-4144-b0f0-e1f906968d08",
        model_config_id: qwen_25_7b_model_config.id,
        provider_id: together_provider.id,
        name: "Qwen/Qwen2.5-7B-Instruct-Turbo"
      })

      rag_evaluation_model_config_provider =
        insert_idempotently(%Exmeralda.LLM.ModelConfigProvider{
          id: "a66ddb78-cfab-4d6f-9f3e-f388da822ed1",
          model_config_id: gpt_oss_model_config.id,
          provider_id: ollama_provider.id,
          name: "gpt-oss:latest"
        })

      _rag_evaluation_model_config =
        insert_idempotently(%Exmeralda.Chats.GenerationEnvironment{
          id: "1667da4f-249a-4e23-ae13-85a4efa5d1f5",
          system_prompt_id: rag_evaluation_system_prompt.id,
          generation_prompt_id: generation_prompt.id,
          model_config_provider_id: rag_evaluation_model_config_provider.id
        })

      rag_judge_system_prompt =
        insert_idempotently(%Exmeralda.LLM.SystemPrompt{
          id: "1db395e2-80d5-4417-9d19-a5fea9c48dc3",
          prompt: @rag_judge_system_prompt
        })

      rag_judge_generation_prompt =
        insert_idempotently(%Exmeralda.Topics.GenerationPrompt{
          id: "c3d4e5f6-a7b8-4c9d-a0e1-f2a3b4c5d6e7",
          prompt: @rag_judge_generation_prompt
        })

      _rag_judge_generation_environment =
        insert_idempotently(%Exmeralda.Chats.GenerationEnvironment{
          id: "a72fb346-f36d-4706-92f0-dc009980c435",
          system_prompt_id: rag_judge_system_prompt.id,
          generation_prompt_id: rag_judge_generation_prompt.id,
          model_config_provider_id: rag_evaluation_model_config_provider.id
        })

      seed_library()
    end
  end

  defp seed_library do
    if File.exists?(@library_fixture_path) do
      Logger.info("Loading Library fixture from #{@library_fixture_path}...")

      fixture =
        @library_fixture_path
        |> File.read!()
        |> Jason.decode!()

      chunks = fixture["chunks"] || []

      if Enum.empty?(chunks) do
        Logger.warning("Library fixture has no chunks - skipping")
      else
        import_library_fixture(fixture, chunks)
      end
    else
      Logger.info("Library fixture not found at #{@library_fixture_path} - skipping")
    end
  end

  defp import_library_fixture(fixture, chunks) do
    library_data = fixture["library"]

    dependencies =
      Enum.map(library_data["dependencies"] || [], fn dep ->
        %Dependency{
          name: dep["name"],
          optional: dep["optional"] || false,
          version_requirement: dep["version_requirement"]
        }
      end)

    library =
      insert_idempotently(
        %Library{
          id: library_data["id"],
          name: library_data["name"],
          version: library_data["version"],
          dependencies: dependencies
        },
        conflict_target: [:name, :version]
      )

    ingestion =
      insert_idempotently(%Ingestion{
        id: fixture["ingestion"]["id"],
        library_id: library.id,
        state: :ready,
        active: true
      })

    chunk_records =
      Enum.map(chunks, fn chunk_data ->
        %{
          id: chunk_data["id"],
          ingestion_id: ingestion.id,
          type: String.to_existing_atom(chunk_data["type"]),
          source: chunk_data["source"],
          content: chunk_data["content"],
          embedding: Pgvector.new(chunk_data["embedding"])
        }
      end)

    chunk_records
    |> Enum.chunk_every(500)
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, batch_num} ->
      {inserted, _} = Repo.insert_all(Chunk, batch, on_conflict: :nothing)
      Logger.info("Chunks batch #{batch_num}: #{inserted} inserted")
    end)

    Logger.info("Library fixture loaded - #{length(chunks)} chunks ready to chat!")
  end

  defp insert_idempotently(schema, opts \\ []) do
    on_conflict = Keyword.get(opts, :on_conflict, :replace_all)
    conflict_target = Keyword.get(opts, :conflict_target, :id)

    Repo.insert!(schema, on_conflict: on_conflict, conflict_target: conflict_target)
  end
end
