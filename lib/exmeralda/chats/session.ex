defmodule Exmeralda.Chats.Session do
  use Exmeralda.Schema
  alias Exmeralda.Accounts.User
  alias Exmeralda.Topics.Ingestion
  alias Exmeralda.Chats.Message

  @title_max_length 255

  schema "chat_sessions" do
    belongs_to :user, User
    belongs_to :ingestion, Ingestion
    belongs_to :original_session, __MODULE__
    belongs_to :copied_from_message, Message
    has_many :messages, Message, preload_order: [asc: :index]
    has_one :library, through: [:ingestion, :library]

    field :title, :string
    field :prompt, :string, virtual: true

    timestamps()
  end

  @duplicate_attrs [:ingestion_id, :title, :original_session_id, :copied_from_message_id]

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

  def duplicate_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @duplicate_attrs)
    |> validate_required(@duplicate_attrs)
    |> foreign_key_constraint(:ingestion_id)
    |> cast_assoc(:messages, with: &Message.duplicate_changeset/2)
  end
end
