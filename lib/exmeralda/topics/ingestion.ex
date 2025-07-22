defmodule Exmeralda.Topics.Ingestion do
  use Exmeralda.Schema

  alias Exmeralda.Topics.Chunk
  alias Exmeralda.Topics.Library

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
end
