defmodule Exmeralda.Repo.Migrations.CreateReactions do
  use Ecto.Migration

  def change do
    alter table(:chat_sessions) do
      modify :user_id, references(:users, on_delete: :nilify_all),
        from: references(:users, on_delete: :delete_all),
        null: true

      modify :ingestion_id, references(:ingestions, on_delete: :restrict),
        from: references(:ingestions, on_delete: :delete_all)
    end

    alter table(:chat_messages) do
      modify :session_id, references(:chat_sessions, on_delete: :restrict),
        from: references(:chat_sessions, on_delete: :delete_all)
    end

    execute("CREATE TYPE reaction_type AS ENUM ('upvote','downvote')", "DROP TYPE reaction_type")

    create table(:chat_reactions) do
      add :message_id, references(:chat_messages, on_delete: :restrict), null: false
      add :type, :reaction_type

      timestamps()
    end

    create unique_index(:chat_reactions, [:message_id])
  end
end
