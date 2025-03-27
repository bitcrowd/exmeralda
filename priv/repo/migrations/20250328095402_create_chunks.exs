defmodule Exmeralda.Repo.Migrations.CreateChunks do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS vector;", "DROP EXTENSION vector")

    execute(
      "CREATE TYPE chunk_type AS ENUM ('code', 'docs');",
      "DROP TYPE chunk_type"
    )

    create table(:chunks) do
      add :source, :text, null: false
      add :content, :text, null: false
      add :embedding, :vector, size: 768, null: false
      add :type, :chunk_type, null: false
      add :library_id, references(:libraries, on_delete: :delete_all), null: false
    end
  end
end
