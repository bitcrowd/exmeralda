defmodule Exmeralda.Chats.Reaction do
  use Exmeralda.Schema

  alias Exmeralda.Accounts.User
  alias Exmeralda.Chats.Message
  alias Exmeralda.Topics.Ingestion

  schema "chat_reactions" do
    # Since chat session and messages can be deleted by the user, we preserve the link
    # to the ingestion on the reaction so that statistics can be made for a given ingestion
    # even if all messages were deleted.
    belongs_to :ingestion, Ingestion
    belongs_to :message, Message
    belongs_to :user, User

    field :type, Ecto.Enum, values: [:upvote, :downvote]

    timestamps()
  end
end
