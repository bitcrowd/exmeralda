defmodule Exmeralda.Repo.Migrations.CreateIngestions do
  use Ecto.Migration

  def up do
    execute(
      "CREATE TYPE ingestion_state AS ENUM ('queued', 'preprocessing', 'chunking', 'embedding', 'failed', 'ready');"
    )

    create table(:ingestions) do
      add :state, :ingestion_state, null: false
      add :library_id, references(:libraries, on_delete: :delete_all), null: false

      timestamps()
    end
  end

  def down do
    drop table(:ingestions)

    execute("DROP TYPE ingestion_state;")
  end
end
