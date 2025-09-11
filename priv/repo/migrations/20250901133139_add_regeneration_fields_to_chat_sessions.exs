defmodule Exmeralda.Repo.Migrations.AddRegenerationFieldsToChatSessions do
  use Ecto.Migration

  def change do
    alter table(:chat_sessions) do
      add :original_session_id, references(:chat_sessions, on_delete: :restrict), null: true
      add :copied_until_message_id, references(:chat_messages, on_delete: :restrict), null: true
    end

    create index(:chat_sessions, [:original_session_id])
    create index(:chat_sessions, [:copied_until_message_id])

    create(
      constraint(
        :chat_sessions,
        :user_id_null_when_original_session,
        check: "original_session_id IS NULL OR user_id IS NULL"
      )
    )

    create(
      constraint(
        :chat_sessions,
        :original_session_when_copied_until_message,
        check: "(original_session_id IS NULL) = (copied_until_message_id IS NULL)"
      )
    )

    alter table(:chat_messages) do
      add :regenerated_from_message_id, references(:chat_messages, on_delete: :restrict),
        null: true
    end
  end
end
