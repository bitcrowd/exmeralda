defmodule Exmeralda.LLM.ModelConfig do
  @moduledoc """
  A ModelConfig represents an LLM model name and its parameterized config,
  that is passed to LangChain.
  """
  use Exmeralda.Schema

  schema "model_configs" do
    field :name, :string
    field :config, :map

    timestamps()
  end
end
