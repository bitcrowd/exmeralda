defmodule Exmeralda.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE chat_role AS ENUM ('user', 'assistant');",
      "DROP TYPE chat_role"
    )

    create table(:chat_messages) do
      add :role, :chat_role, null: false
      add :index, :integer, null: false
      add :content, :text, null: false
      add :incomplete, :boolean, null: false, default: false
      add :session_id, references(:chat_sessions, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:chat_messages, [:session_id, :index])

    alter table(:chat_sessions) do
      add :title, :string, null: false
    end
  end
end
