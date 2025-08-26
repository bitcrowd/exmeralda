defmodule Exmeralda.Environment.Provider do
  @moduledoc """
  A provider is a third-party API providing access to AI models.
  """
  use Exmeralda.Schema

  schema "providers" do
    field :type, Ecto.Enum, values: [:groq, :lambda, :together, :hyperbolic, :mock]
    field :endpoint, :string

    timestamps()
  end
end
