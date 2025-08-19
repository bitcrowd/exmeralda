defmodule Exmeralda.Repo.Migrations.RemoveLibraryIdFromChunks do
  use Ecto.Migration

  def up do
    alter table("chunks") do
      remove :library_id
    end
  end

  def down do
    alter table("chunks") do
      add :library_id, references(:libraries, on_delete: :delete_all), null: true
    end

    execute("""
    UPDATE
      chunks
    SET
      library_id = ingestions.library_id
    FROM
      ingestions
    WHERE
      chunks.ingestion_id = ingestions.id;
    """)

    alter table("chunks") do
      modify :library_id, references(:libraries, on_delete: :delete_all),
        null: false,
        from: references(:libraries, on_delete: :delete_all)
    end
  end
end
