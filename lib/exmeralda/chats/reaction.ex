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

  @fields [:message_id, :user_id, :type]

  @doc false
  def changeset(message \\ %__MODULE__{}, attrs) do
    message
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> unique_constraint([:message_id, :user_id])
  end
end
