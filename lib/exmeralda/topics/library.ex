defmodule Exmeralda.Topics.Library do
  use Exmeralda.Schema

  alias Exmeralda.Topics.{Dependency, Chunk}

  @derive {Flop.Schema,
           filterable: [:name, :version],
           sortable: [:name, :version],
           default_limit: 20,
           max_limit: 100}

  schema "libraries" do
    field :name, :string
    field :version, :string
    embeds_many :dependencies, Dependency, on_replace: :delete

    has_many :chunks, Chunk

    timestamps()
  end

  @doc false
  def changeset(library, attrs) do
    library
    |> cast(attrs, [:name, :version])
    |> validate_required([:name, :version])
    |> validate_format(:name, ~r/^[a-z][a-z0-9_]*?[a-z0-9]$/)
    |> validate_version()
    |> cast_embed(:dependencies)
    |> unique_constraint([:name, :version])
  end

  defp validate_version(changeset) do
    validate_change(changeset, :version, fn _, version ->
      case Version.parse(version) do
        {:ok, _} -> []
        :error -> [version: {"has invalid format", [validation: :version]}]
      end
    end)
  end
end
