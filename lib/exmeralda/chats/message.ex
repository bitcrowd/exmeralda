defmodule Exmeralda.Chats.Message do
  use Exmeralda.Schema

  alias Exmeralda.Chats.{Session, Source}

  schema "chat_messages" do
    field :index, :integer
    field :role, Ecto.Enum, values: [:user, :assistant]
    field :content, :string
    field :incomplete, :boolean, default: false
    belongs_to :session, Session
    has_many :sources, Source

    has_many :source_chunks,
      through: [:sources, :chunk],
      preload_order: [asc: :type, asc: :source]

    timestamps()
  end

  @doc false
  def changeset(message \\ %__MODULE__{}, attrs) do
    message
    |> cast(attrs, [:role, :index, :content, :incomplete])
    |> validate_required([:role, :index, :content, :incomplete])
  end
end
