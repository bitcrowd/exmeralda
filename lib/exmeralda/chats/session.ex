defmodule Exmeralda.Chats.Session do
  use Exmeralda.Schema

  schema "chat_sessions" do
    timestamps()
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [])
    |> validate_required([])
  end
end
