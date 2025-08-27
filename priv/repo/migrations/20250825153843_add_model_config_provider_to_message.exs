defmodule Exmeralda.Repo.Migrations.AddModelConfigAndProviderToMessage do
  use Ecto.Migration

  def change do
    alter table(:chat_messages) do
      add :model_config_id, references(:model_configs, on_delete: :restrict), null: true
      add :provider_id, references(:providers, on_delete: :restrict), null: true
    end
  end
end
