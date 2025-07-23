defmodule Exmeralda.Chats.Session do
  use Exmeralda.Schema
  alias Exmeralda.Accounts.User
  alias Exmeralda.Topics.{Ingestion, Library}
  alias Exmeralda.Chats.Message

  @title_max_length 255

  schema "chat_sessions" do
    field :title, :string
    field :prompt, :string, virtual: true
    belongs_to :user, User
    belongs_to :library, Library
    belongs_to :ingestion, Ingestion
    has_many :messages, Message, preload_order: [asc: :index]

    timestamps()
  end

  @doc false
  def create_changeset(session, attrs) do
    changeset =
      session
      |> cast(attrs, [:library_id, :ingestion_id, :prompt])
      |> validate_required([:library_id, :ingestion_id, :prompt])

    title =
      changeset
      |> get_change(:prompt, "")
      |> String.slice(0, @title_max_length)

    set_title_changeset(changeset, title)
  end

  @doc false
  def set_title_changeset(session, title) do
    change(session, title: title)
  end
end
