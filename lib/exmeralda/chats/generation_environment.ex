defmodule Exmeralda.Chats.GenerationEnvironment do
  @moduledoc """
  A generation environment describe the model, provider, and prompts that
  were used to generate a message.
  """
  use Exmeralda.Schema
  alias Exmeralda.LLM.ModelConfigProvider

  schema "generation_environments" do
    belongs_to :model_config_provider, ModelConfigProvider

    timestamps()
  end
end
