defmodule Exmeralda.Topics.Ingestion do
  use Exmeralda.Schema

  alias Exmeralda.Topics.Chunk
  alias Exmeralda.Topics.Library

  @derive {
    Flop.Schema,
    filterable: [:state],
    sortable: [:state, :inserted_at, :updated_at],
    default_limit: 20,
    max_limit: 100,
    default_order: %{
      order_by: [:inserted_at],
      order_directions: [:desc]
    }
  }

  schema "ingestions" do
    field :state, Ecto.Enum,
      # TODO: Consider prod ingestion in preprocessing or chunking states!!
      values: [:queued, :preprocessing, :chunking, :embedding, :failed, :ready]

    belongs_to :library, Library
    has_many :chunks, Chunk
    belongs_to :job, Oban.Job, foreign_key: :job_id, type: :integer

    timestamps()
  end

  @doc false
  def changeset(ingestion \\ %__MODULE__{}, attrs) do
    ingestion
    |> cast(attrs, [:state, :library_id])
    |> validate_required([:state, :library_id])
  end

  @doc false
  def set_state(ingestion, state) do
    # TODO: validate state transitions
    change(ingestion, state: state)
  end

  def set_ingestion_job_id(ingestion, job_id) do
    change(ingestion, job_id: job_id)
  end
end
