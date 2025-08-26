defmodule Exmeralda.Environment.ModelConfig do
  @moduledoc """
  A ModelConfig represents an LLM model name and its parameterized config,
  that is passed to LangChain.

  See `LangChain.ChatModels.ChatOpenAI.new!`.
  """
  use Exmeralda.Schema

  schema "model_configs" do
    field :name, :string
    field :config, :map

    timestamps()
  end
end
