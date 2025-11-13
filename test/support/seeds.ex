defmodule Exmeralda.Seeds do
  alias Exmeralda.Repo

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

  def run do
    if Mix.env() == :dev do
      _system_prompt =
        insert_idempotently(%Exmeralda.LLM.SystemPrompt{
          id: "c49195b4-daca-42af-835d-bdb928986d5c",
          prompt: @default_system_prompt,
          active: true
        })

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

      ollama_provider =
        insert_idempotently(%Exmeralda.LLM.Provider{
          id: "1d7c3ee6-d189-4c85-ad59-116f92fdafd0",
          type: :ollama,
          name: "ollama_ai",
          config: %{}
        })

      ollama_model_config =
        insert_idempotently(%Exmeralda.LLM.ModelConfig{
          id: "7420d870-b10b-46ba-b30b-5c4630ee3a99",
          name: "llama3.2:latest",
          # Ollama has a context window of 2048 by default, and this is also Langchain's default
          # https://github.com/brainlid/langchain/blob/47de3e44e09c51a811e1e3262e161e1a92a4b77d/lib/chat_models/chat_ollama_ai.ex#L114
          # This context window is likely too small for our prompts.
          # Setting `num_ctx` allows to increase the context window.
          #
          # `num_predict: -2` means that the rest of the models context can be used to predit tokens for the response.
          # The default is 128 and leads to truncated responses with the increased `num_ctx`.
          config: %{stream: true, num_ctx: 32_768, num_predict: -2}
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

      qwen_25_32b_model_config =
        insert_idempotently(%Exmeralda.LLM.ModelConfig{
          id: "eff70662-1576-491d-a1ef-1d025772e638",
          name: "qwen25-coder-32b",
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
        model_config_id: qwen_25_32b_model_config.id,
        provider_id: together_provider.id,
        name: "Qwen/Qwen2.5-Coder-32B-Instruct"
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
    end
  end

  defp insert_idempotently(schema, conflict_target \\ :id) do
    Repo.insert!(schema, on_conflict: :replace_all, conflict_target: conflict_target)
  end
end
