defmodule Exmeralda.Environment.GenerationConfig do
  @moduledoc """
  GenerationConfig stores the various parameters that can be associated
  to generating a message from an agent.

  """
  use Exmeralda.Schema
  alias Exmeralda.Environment.{ModelConfigProvider}

  schema "generation_configs" do
    belongs_to(:model_config_provider, ModelConfigProvider)
    # System prompt and template prompt will be added later.

    timestamps()
  end
end
