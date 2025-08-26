defmodule Exmeralda.Seeds do
  alias Exmeralda.Repo

  def run do
    if Mix.env() == :dev do
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

      qwen_25_32b_model_config =
        insert_idempotently(%Exmeralda.LLM.ModelConfig{
          id: "eff70662-1576-491d-a1ef-1d025772e637",
          name: "qwen25-coder-32b",
          config: %{stream: true}
        })

      insert_idempotently(%Exmeralda.LLM.ModelConfigProvider{
        id: "073a0faf-024b-4144-b0f0-e1f906968d08",
        model_config_id: qwen_25_32b_model_config.id,
        provider_id: together_provider.id,
        name: "Qwen/Qwen2.5-Coder-32B-Instruct"
      })
    end

    if Mix.env() == :dev do
      provider =
        insert_idempotently(
          %Exmeralda.Environment.Provider{
            id: "460d1461-6ff3-49bf-b423-5a9e8f440ba9",
            type: :together,
            endpoint: "https://api.together.xyz/v1/chat/completions"
          },
          :type
        )

      model_config =
        insert_idempotently(%Exmeralda.Environment.ModelConfig{
          id: "b316dea6-eba5-4fd4-ae6d-5e67f151cb4c",
          name: "qwen25-coder-32b",
          config: %{stream: true}
        })

      model_config_provider =
        insert_idempotently(
          %Exmeralda.Environment.ModelConfigProvider{
            id: "460d1461-6ff3-49bf-b423-5a9e8f440ba8",
            model_config_id: model_config.id,
            provider_id: provider.id,
            name: "Qwen/Qwen2.5-Coder-32B-Instruct"
          },
          [:provider_id, :model_config_id]
        )

      insert_idempotently(
        %Exmeralda.Environment.GenerationConfig{
          id: "5242404c-ca9e-40f3-a84e-c044195379ed",
          model_config_provider_id: model_config_provider.id
        },
        :model_config_provider_id
      )
    end
  end

  defp insert_idempotently(schema, conflict_target \\ :id) do
    Repo.insert!(schema, on_conflict: :replace_all, conflict_target: conflict_target)
  end
end
