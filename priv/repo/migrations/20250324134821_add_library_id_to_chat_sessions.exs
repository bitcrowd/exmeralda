defmodule Exmeralda.Repo.Migrations.AddLibraryIdToChatSessions do
  use Ecto.Migration

  def change do
    alter table("chat_sessions") do
      add :library_id, references(:libraries, on_delete: :delete_all), null: false
    end
  end
end
