defmodule Exmeralda.Repo.Migrations.CreateLibraries do
  use Ecto.Migration

  def change do
    create table(:libraries) do
      add :name, :string
      add :version, :string
      add :dependencies, :map

      timestamps()
    end

    create unique_index(:libraries, [:name, :version])
  end
end
