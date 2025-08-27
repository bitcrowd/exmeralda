defmodule Exmeralda.Chats.LLMTest do
  use Exmeralda.DataCase

  alias Exmeralda.Chats.LLM

  describe "stream_responses/3" do
    test "raises when model config provider does not exist" do
      assert_raise Ecto.NoResultsError, fn -> LLM.stream_responses([], uuid(), %{}) end
    end

    test "stream responses for mock provider" do
      provider = insert(:provider, type: :mock)
      model_config_provider = insert(:model_config_provider, provider: provider)

      generation_environment =
        insert(:generation_environment, model_config_provider: model_config_provider)

      assert {:ok,
              %LangChain.Chains.LLMChain{
                llm: %Exmeralda.LLM.Fake{
                  name: "MockChatModel",
                  version: "1.0",
                  callbacks: []
                },
                messages: [prompt_message, response]
              }} = LLM.stream_responses([], generation_environment.id, %{})

      assert prompt_message.content =~ "You are an expert in Elixir programming"
      assert response.content == "This is a streaming response!"
    end
  end

  describe "llm/1" do
    test "with a mock provider" do
      provider = insert(:provider, type: :mock)
      model_config = insert(:model_config)

      model_config_provider =
        insert(:model_config_provider, model_config: model_config, provider: provider)

      assert LLM.llm(model_config_provider) == %Exmeralda.LLM.Fake{
               name: "MockChatModel",
               version: "1.0",
               callbacks: []
             }
    end

    test "with an ollama provider" do
      provider = insert(:provider, type: :ollama)
      model_config = insert(:model_config, name: "fake-model", config: %{"stream" => true})

      model_config_provider =
        insert(:model_config_provider,
          model_config: model_config,
          provider: provider,
          name: "Fake-Model"
        )

      assert %LangChain.ChatModels.ChatOllamaAI{model: "Fake-Model", stream: true} =
               LLM.llm(model_config_provider)
    end

    test "with an openai provider" do
      provider =
        insert(:provider,
          type: :openai,
          name: "foo_ai",
          config: %{"endpoint" => "https://example.com/v1/chat/completions"}
        )

      model_config = insert(:model_config, name: "qwen25", config: %{"stream" => true})

      model_config_provider =
        insert(:model_config_provider,
          model_config: model_config,
          provider: provider,
          name: "Qwen/Qwen25"
        )

      assert %LangChain.ChatModels.ChatOpenAI{
               model: "Qwen/Qwen25",
               stream: true,
               endpoint: "https://example.com/v1/chat/completions",
               api_key: "abcde"
             } = LLM.llm(model_config_provider)
    end
  end
end
