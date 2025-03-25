defmodule Exmeralda.Topics.Dependency do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :version_requirement, :string
    field :optional, :boolean, default: false
  end

  def changeset(dependency, params) do
    dependency
    |> cast(params, [:name, :version_requirement, :optional])
    |> validate_required([:name, :version_requirement])
    |> validate_version_requirement()
  end

  defp validate_version_requirement(changeset) do
    validate_change(changeset, :version_requirement, fn _, requirement ->
      case Version.parse_requirement(requirement) do
        {:ok, _} ->
          []

        :error ->
          [version_requirement: {"has invalid format", [validation: :version_requirement]}]
      end
    end)
  end
end
