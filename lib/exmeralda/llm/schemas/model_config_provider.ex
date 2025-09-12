defmodule Exmeralda.LLM.ModelConfigProvider do
  @moduledoc """
  ModelConfigProvider is joint model between ModelConfig and Provider.
  This joint model is required because the name of a model can be differently
  spelled depending on the provider.

  For example, `Qwen/Qwen2.5-Coder-32B-Instruct` in Hyperbolic is spelled
  `qwen25-coder-32b-instruct` in Lambda.
  """
  use Exmeralda.Schema
  alias Exmeralda.LLM.{ModelConfig, Provider}

  schema "model_config_providers" do
    belongs_to :model_config, ModelConfig
    belongs_to :provider, Provider

    field :name, :string

    timestamps()
  end
end
