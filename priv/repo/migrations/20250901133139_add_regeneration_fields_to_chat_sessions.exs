defmodule Exmeralda.Repo.Migrations.AddRegenerationFieldsToChatSessions do
  use Ecto.Migration

  def change do
    alter table(:chat_sessions) do
      add :original_session_id, references(:chat_sessions, on_delete: :restrict), null: true
      add :copied_from_message_id, references(:chat_messages, on_delete: :restrict), null: true
    end

    create index(:chat_sessions, [:original_session_id])
    create index(:chat_sessions, [:copied_from_message_id])

    create(
      constraint(
        :chat_sessions,
        :used_id_null_when_regeneration_fields,
        check:
          "NOT (original_session_id IS NOT NULL AND copied_from_message_id IS NOT NULL AND user_id IS NOT NULL)"
      )
    )

    create(
      constraint(
        :chat_sessions,
        :original_session_when_copied_from_message,
        check: "(original_session_id IS NULL) = (copied_from_message_id IS NULL)"
      )
    )
  end
end
