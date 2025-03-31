defmodule Exmeralda.Repo.Migrations.AddVectorToChunks do
  use Ecto.Migration

  def change do
    alter table(:chunks) do
      add :search, :tsvector, generated: "ALWAYS AS (to_tsvector('english', content)) STORED"
    end

    create index(:chunks, :search, using: "GIN")
  end
end
