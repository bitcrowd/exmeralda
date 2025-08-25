defmodule Exmeralda.Repo.Migrations.CreateGenerationConfig do
  use Ecto.Migration

  def change do
    create table(:generation_configs) do
      add :model_config_provider_id, references(:model_config_providers, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:generation_configs, [:model_config_provider_id])

    execute("""
      INSERT INTO generation_configs (id, model_config_provider_id, inserted_at, updated_at)
      SELECT gen_random_uuid(), id, NOW(), NOW() from model_config_providers;
    """, "")

    alter table(:chat_messages) do
      add :generation_config_id, references(:generation_configs, on_delete: :restrict), null: true
    end
  end
end
