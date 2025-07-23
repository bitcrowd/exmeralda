defmodule Exmeralda.Repo.Migrations.AddIngestionIdToChatSessions do
  use Ecto.Migration

  def up do
    alter table("chat_sessions") do
      add :ingestion_id, references(:ingestions, on_delete: :delete_all), null: true
    end

    flush()

    execute("""
      UPDATE
        chat_sessions
      SET
        ingestion_id = ingestions.id
      FROM
        ingestions
      WHERE
        chat_sessions.ingestion_id IS NULL
        AND chat_sessions.library_id = ingestions.library_id;
    """)

    flush()

    execute("""
      ALTER TABLE
        chat_sessions ALTER COLUMN ingestion_id
      SET
        NOT NULL;
    """)
  end

  def down do
    alter table("chat_sessions") do
      remove :ingestion_id
    end
  end
end
