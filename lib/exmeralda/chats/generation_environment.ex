defmodule Exmeralda.Chats.GenerationEnvironment do
  @moduledoc """
  A generation environment describe the model, provider, and prompts that
  were used to generate a message.
  """
  use Exmeralda.Schema
  alias Exmeralda.LLM.{ModelConfigProvider, SystemPrompt}

  schema "generation_environments" do
    belongs_to :model_config_provider, ModelConfigProvider
    belongs_to :system_prompt, SystemPrompt

    timestamps()
  end
end
