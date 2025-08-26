defmodule Exmeralda.Repo.Migrations.AddGenerationConfigToMessage do
  use Ecto.Migration

  def change do
    alter table(:chat_messages) do
      add :generation_config_id, references(:generation_configs, on_delete: :restrict), null: true
    end
  end
end
