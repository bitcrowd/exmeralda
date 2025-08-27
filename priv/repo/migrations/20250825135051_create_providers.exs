defmodule Exmeralda.Repo.Migrations.CreateProviders do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE provider_type AS ENUM ('ollama', 'openai', 'mock');",
      "DROP TYPE provider_type;"
    )

    create table(:providers) do
      add :type, :provider_type, null: false
      add :name, :string, null: false
      add :config, :map, null: false, default: %{}

      timestamps()
    end

    create unique_index(:providers, [:type, :name])
  end
end
