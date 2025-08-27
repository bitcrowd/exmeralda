defmodule Exmeralda.Chats.Message do
  use Exmeralda.Schema

  alias Exmeralda.Chats.{Reaction, Session, Source}
  alias Exmeralda.LLMs.{ModelConfig, Provider}

  schema "chat_messages" do
    field :index, :integer
    field :role, Ecto.Enum, values: [:user, :assistant]
    field :content, :string
    field :incomplete, :boolean, default: false
    belongs_to :session, Session
    belongs_to :model_config, ModelConfig
    belongs_to :provider, Provider
    has_many :sources, Source

    has_many :source_chunks,
      through: [:sources, :chunk],
      preload_order: [asc: :type, asc: :source]

    has_one :reaction, Reaction

    timestamps()
  end

  @attrs [:session_id, :model_config_id, :provider_id, :role, :index, :content, :incomplete]
  @doc false
  def changeset(message \\ %__MODULE__{}, attrs) do
    message
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
  end
end
