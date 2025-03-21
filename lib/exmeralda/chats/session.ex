defmodule Exmeralda.Chats.Session do
  use Exmeralda.Schema
  alias Exmeralda.Accounts.User

  schema "chat_sessions" do
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [])
    |> validate_required([])
  end
end
