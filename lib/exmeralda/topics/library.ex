defmodule Exmeralda.Topics.Library do
  use Exmeralda.Schema

  alias Exmeralda.Topics.Dependency

  schema "libraries" do
    field :name, :string
    field :version, :string
    embeds_many :dependencies, Dependency

    timestamps()
  end

  @doc false
  def changeset(library, attrs) do
    library
    |> cast(attrs, [:name, :version])
    |> validate_required([:name, :version])
    |> validate_version()
    |> cast_embed(:dependencies)
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
