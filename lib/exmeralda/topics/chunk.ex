defmodule Exmeralda.Topics.Chunk do
  use Exmeralda.Schema

  alias Exmeralda.Topics.Library

  @derive {Flop.Schema,
           filterable: [:type, :source],
           sortable: [:type, :source],
           default_limit: 20,
           max_limit: 100}

  schema "chunks" do
    field :type, Ecto.Enum, values: [:code, :docs]
    field :source, :string
    field :content, :string
    field(:embedding, Pgvector.Ecto.Vector)
    belongs_to(:library, Library)
  end

  def set_embedding(chunk, embedding) do
    change(chunk, embedding: embedding)
  end
end
