defmodule Exmeralda.Chats.Session do
  use Exmeralda.Schema
  alias Exmeralda.Accounts.User
  alias Exmeralda.Topics.Library

  schema "chat_sessions" do
    belongs_to :user, User
    belongs_to :library, Library

    timestamps()
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:library_id])
    |> validate_required([:library_id])
  end
end
