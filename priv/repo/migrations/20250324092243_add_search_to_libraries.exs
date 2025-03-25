defmodule Exmeralda.Repo.Migrations.AddSearchToLibraries do
  use Ecto.Migration

  def change do
    alter table("libraries") do
      add :search, :tsvector, generated: "ALWAYS AS (
        setweight(to_tsvector('simple', name), 'A') ||
        setweight(to_tsvector('simple', version), 'B')
      ) STORED"
    end

    create index(:libraries, :search, using: "GIN")
  end
end
