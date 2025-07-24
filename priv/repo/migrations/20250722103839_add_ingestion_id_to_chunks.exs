defmodule Exmeralda.Repo.Migrations.AddIngestionIdToChunks do
  use Ecto.Migration

  def up do
    alter table(:chunks) do
      add :ingestion_id, references(:ingestions, on_delete: :delete_all), null: true
    end

    flush()

    execute("""
      UPDATE
        chunks
      SET
        ingestion_id = ingestions.id
      FROM
        ingestions
      WHERE
        chunks.ingestion_id IS NULL
        AND chunks.library_id = ingestions.library_id
    """)

    flush()

    execute("""
      ALTER TABLE
        chunks ALTER COLUMN ingestion_id
      SET
        NOT NULL;
    """)
  end

  def down do
    alter table(:chunks) do
      remove :ingestion_id
    end
  end
end
