defmodule Exmeralda.Repo.Migrations.RestrictModelConfigProviderOnGenerationEnvironment do
  use Ecto.Migration

  def change do
    alter table(:generation_environments) do
      modify :model_config_provider_id, references(:model_config_providers, on_delete: :restrict),
        null: false,
        from: references(:model_config_providers, on_delete: :delete_all)
    end
  end
end
