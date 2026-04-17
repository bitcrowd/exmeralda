defmodule Exmeralda.Chats.GenerationEnvironment do
  @moduledoc """
  A generation environment describe the model, provider, and prompts that
  were used to generate a message.
  """
  use Exmeralda.Schema
  alias Exmeralda.LLM.{ModelConfigProvider, SystemPrompt}
  alias Exmeralda.Topics.GenerationPrompt

  @derive {
    Flop.Schema,
    filterable: [],
    sortable: [:inserted_at],
    default_limit: 20,
    max_limit: 100,
    default_order: %{
      order_by: [:inserted_at],
      order_directions: [:desc]
    }
  }

  schema "generation_environments" do
    belongs_to :model_config_provider, ModelConfigProvider
    belongs_to :system_prompt, SystemPrompt
    belongs_to :generation_prompt, GenerationPrompt

    timestamps()
  end
end
