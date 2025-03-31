defmodule Exmeralda.Chats.Message do
  use Exmeralda.Schema

  alias Exmeralda.Chats.Session

  schema "chat_messages" do
    field :index, :integer
    field :role, Ecto.Enum, values: [:user, :assistant]
    field :content, :string
    field :incomplete, :boolean, default: false
    belongs_to :session, Session

    timestamps()
  end

  @doc false
  def changeset(message \\ %__MODULE__{}, attrs) do
    message
    |> cast(attrs, [:role, :index, :content, :incomplete])
    |> validate_required([:role, :index, :content, :incomplete])
  end
end
