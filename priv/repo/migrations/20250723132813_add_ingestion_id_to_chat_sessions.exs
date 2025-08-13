defmodule Exmeralda.Repo.Migrations.AddIngestionIdToChatSessions do
  use Ecto.Migration

  def up do
    alter table("chat_sessions") do
      add :ingestion_id, references(:ingestions, on_delete: :delete_all), null: true
    end

    execute("""
      UPDATE
        chat_sessions
      SET
        ingestion_id = ingestions.id
      FROM
        ingestions
      WHERE
        chat_sessions.library_id = ingestions.library_id;
    """)

    alter table("chat_sessions") do
      modify :ingestion_id, references(:ingestions, on_delete: :delete_all),
        null: false,
        from: references(:ingestions, on_delete: :delete_all)

      remove :library_id
    end
  end

  def down do
    alter table("chat_sessions") do
      add :library_id, references(:libraries, on_delete: :delete_all), null: true
    end

    execute("""
      UPDATE
        chat_sessions
      SET
        library_id = ingestions.library_id
      FROM
        ingestions
      WHERE
        chat_sessions.ingestion_id = ingestions.id;
    """)

    alter table("chat_sessions") do
      modify :library_id, references(:libraries, on_delete: :delete_all),
        null: false,
        from: references(:libraries, on_delete: :delete_all)

      remove :ingestion_id
    end
  end
end
