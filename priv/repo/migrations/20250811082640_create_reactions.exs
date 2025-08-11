defmodule Exmeralda.Repo.Migrations.CreateReactions do
  use Ecto.Migration

  def change do
    execute("CREATE TYPE reaction_type AS ENUM ('upvote','downvote')", "DROP TYPE reaction_type")

    create table(:chat_reactions) do
      add :message_id, references(:chat_messages, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :type, :reaction_type

      timestamps()
    end

    create unique_index(:chat_reactions, [:message_id, :user_id])
  end
end
