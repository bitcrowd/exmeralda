defmodule Exmeralda.Repo.Migrations.AddNotNullConstraintToIngestionId do
  use Ecto.Migration

  def change do
    execute(
      "ALTER TABLE chunks ALTER COLUMN ingestion_id SET NOT NULL;",
      "ALTER TABLE chunks ALTER COLUMN ingestion_id DROP NOT NULL;"
    )
  end
end
