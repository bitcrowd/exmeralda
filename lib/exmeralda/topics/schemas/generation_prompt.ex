defmodule Exmeralda.Topics.GenerationPrompt do
  @moduledoc """
  Generation prompt that is passed to the RAG generation builder.

  The `prompt` string can contain two placeholders:
  - `%{query}`
  - `%{context}`

  The query being the question from the user, and the context is provided
  by the ingestion's chunks.
  """
  use Exmeralda.Schema

  @derive {
    Flop.Schema,
    filterable: [],
    sortable: [:inserted_at],
    default_limit: 20,
    default_order: %{
      order_by: [:inserted_at],
      order_directions: [:desc]
    }
  }

  schema "generation_prompts" do
    field :prompt, :string
    field :deletable, :boolean, virtual: true

    timestamps()
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:prompt])
    |> validate_required([:prompt])
  end
end
