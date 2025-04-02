defmodule Exmeralda.Chats.Source do
  use Exmeralda.Schema

  alias Exmeralda.Topics.Chunk
  alias Exmeralda.Chats.Message

  schema "chat_sources" do
    belongs_to :chunk, Chunk
    belongs_to :message, Message
  end
end
