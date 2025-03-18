defmodule Exmeralda.Repo.Migrations.CreateChatSessions do
  use Ecto.Migration

  def change do
    create table(:chat_sessions) do
      timestamps()
    end
  end
end
