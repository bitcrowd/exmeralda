defmodule Exmeralda.Chats.GenerationEnvironment do
  @moduledoc """
  A generation environment describe the model, provider, and prompts that
  were used to generate a message.
  """
  use Exmeralda.Schema
  alias Exmeralda.LLM.{ModelConfigProvider, SystemPrompt}
  alias Exmeralda.Topics.GenerationPrompt

  schema "generation_environments" do
    belongs_to :model_config_provider, ModelConfigProvider
    belongs_to :system_prompt, SystemPrompt
    belongs_to :generation_prompt, GenerationPrompt

    timestamps()
  end
end
