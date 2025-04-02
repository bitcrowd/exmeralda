defmodule Exmeralda.Topics.Chunk do
  use Exmeralda.Schema

  alias Exmeralda.Topics.Library

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
