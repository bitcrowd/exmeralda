defmodule Exmeralda.LLM.SystemPrompt do
  @moduledoc """
  System prompt that is passed to the LLM model.
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

  schema "system_prompts" do
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
