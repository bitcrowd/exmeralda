defmodule Exmeralda.Topics.Ingestion do
  use Exmeralda.Schema

  alias Exmeralda.Topics.Chunk
  alias Exmeralda.Topics.Library

  @derive {Flop.Schema,
           filterable: [:state],
           sortable: [:state, :inserted_at, :updated_at],
           default_limit: 20,
           max_limit: 100,
           default_order: %{
             order_by: [:updated_at],
             order_directions: [:desc]
           }}

  schema "ingestions" do
    field :state, Ecto.Enum,
      values: [:queued, :preprocessing, :chunking, :embedding, :failed, :ready]

    belongs_to :library, Library
    has_many :chunks, Chunk

    timestamps()
  end

  @doc false
  def changeset(ingestion \\ %__MODULE__{}, attrs) do
    ingestion
    |> cast(attrs, [:state, :library_id])
    |> validate_required([:state, :library_id])
  end

  @doc false
  def set_state(ingestion, state) do
    change(ingestion, state: state)
  end
end
