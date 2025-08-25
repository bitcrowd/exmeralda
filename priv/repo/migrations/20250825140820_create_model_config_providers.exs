defmodule Exmeralda.Repo.Migrations.CreateModelConfigProviders do
  use Ecto.Migration

  def change do
    create table(:model_config_providers) do
      add :model_config_id, references(:model_configs, on_delete: :delete_all), null: false
      add :provider_id, references(:providers, on_delete: :delete_all), null: false
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:model_config_providers, [:model_config_id, :provider_id])
  end
end
