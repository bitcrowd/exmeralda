defmodule Exmeralda.LLM.Provider do
  @moduledoc """
  A provider is a third-party providing access to AI models.
  """
  use Exmeralda.Schema

  schema "providers" do
    field :type, Ecto.Enum, values: [:ollama, :openai, :mock]
    field :name, :string
    field :config, :map

    timestamps()
  end
end
