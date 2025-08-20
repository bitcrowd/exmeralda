defmodule Exmeralda.Chats.Reaction do
  use Exmeralda.Schema

  alias Exmeralda.Accounts.User
  alias Exmeralda.Chats.Message

  schema "chat_reactions" do
    belongs_to :message, Message
    belongs_to :user, User

    field :type, Ecto.Enum, values: [:upvote, :downvote]

    timestamps()
  end
end
