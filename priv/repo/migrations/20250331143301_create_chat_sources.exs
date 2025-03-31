defmodule Exmeralda.Repo.Migrations.CreateChatSources do
  use Ecto.Migration

  def change do
    create table(:chat_sources) do
      add :chunk_id, references(:chunks, on_delete: :delete_all)
      add :message_id, references(:chat_messages, on_delete: :delete_all)
    end

    create index(:chat_sources, [:message_id])
  end
end
