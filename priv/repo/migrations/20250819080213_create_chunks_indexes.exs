defmodule Exmeralda.Repo.Migrations.CreateChunksIndexes do
  use Ecto.Migration

  def change do
    create index("chunks", [:library_id])
    create index("chunks", [:ingestion_id])
  end
end
