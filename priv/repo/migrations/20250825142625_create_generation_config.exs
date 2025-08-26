defmodule Exmeralda.Repo.Migrations.CreateGenerationConfig do
  use Ecto.Migration

  def change do
    create table(:generation_configs) do
      add :model_config_provider_id, references(:model_config_providers, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:generation_configs, [:model_config_provider_id])
  end
end
