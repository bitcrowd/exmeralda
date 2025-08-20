defmodule Exmeralda.Chats.Reaction do
  use Exmeralda.Schema

  alias Exmeralda.Chats.Message

  schema "chat_reactions" do
    belongs_to :message, Message

    field :type, Ecto.Enum, values: [:upvote, :downvote]

    timestamps()
  end
end
