defmodule Exmeralda.Repo.Migrations.AddIngestionIdToChunks do
  use Ecto.Migration

  def up do
    alter table(:chunks) do
      add :ingestion_id, references(:ingestions, on_delete: :delete_all), null: true
    end
  end

  def down do
    alter table(:chunks) do
      remove :ingestion_id
    end
  end
end
