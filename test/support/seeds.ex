defmodule Exmeralda.Seeds do
  alias Exmeralda.Repo

  def run do
    if Mix.env() == :dev do
      provider =
        insert_idempotently(%Exmeralda.Environment.Provider{
          id: "62b47ee3-17ec-4c41-ac5e-3d8d6c0ac83d",
          type: :mock,
          endpoint: "http://localhost:4000/v1/chat/completions"
        })

      model_config =
        insert_idempotently(%Exmeralda.Environment.ModelConfig{
          id: "8270fc8e-d0df-4af1-9ddf-b208f5a8059e",
          name: "fake-model",
          config: %{}
        })

      model_config_provider =
        insert_idempotently(%Exmeralda.Environment.ModelConfigProvider{
          id: "1bf8d6a1-9c25-4f02-8c1b-767ebf11e37b",
          model_config_id: model_config.id,
          provider_id: provider.id,
          name: "Fake/Fake-model"
        })

      insert_idempotently(%Exmeralda.Environment.GenerationConfig{
        id: "2305268e-c07e-47dc-9e8e-3cb3508ce2d4",
        model_config_provider_id: model_config_provider.id
      })
    end
  end

  defp insert_idempotently(schema, conflict_target \\ :id) do
    Repo.insert!(schema, on_conflict: :replace_all, conflict_target: conflict_target)
  end
end
