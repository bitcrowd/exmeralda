defmodule Exmeralda.Repo.Migrations.AddUserIdToChats do
  use Ecto.Migration

  def change do
    alter table("chat_sessions") do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end
  end
end
