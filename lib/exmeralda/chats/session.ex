defmodule Exmeralda.Chats.Session do
  use Exmeralda.Schema
  alias Exmeralda.Accounts.User
  alias Exmeralda.Topics.Ingestion
  alias Exmeralda.Chats.Message

  @title_max_length 255

  schema "chat_sessions" do
    field :title, :string
    field :prompt, :string, virtual: true
    belongs_to :user, User
    belongs_to :ingestion, Ingestion
    has_many :messages, Message, preload_order: [asc: :index]
    has_one :library, through: [:ingestion, :library]

    timestamps()
  end

  @doc false
  def create_changeset(session, attrs) do
    changeset =
      session
      |> cast(attrs, [:ingestion_id, :prompt])
      |> validate_required([:ingestion_id, :prompt])
      |> foreign_key_constraint(:ingestion_id)

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

  @doc false
  def unset_user_changeset(session) do
    change(session, user_id: nil)
  end
end
