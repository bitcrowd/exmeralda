defmodule Exmeralda.Repo.Migrations.CreateGenerationEnvironment do
  use Ecto.Migration

  def change do
    create table(:generation_environments) do
      add :model_config_provider_id, references(:model_config_providers, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:generation_environments, [:model_config_provider_id])

    alter table(:chat_messages) do
      add :generation_environment_id, references(:generation_environments, on_delete: :restrict),
        null: true
    end
  end
end
