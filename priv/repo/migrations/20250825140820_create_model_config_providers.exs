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

    execute("""
      INSERT INTO model_config_providers (id, model_config_id, provider_id, name, inserted_at, updated_at)
      VALUES
        (
          gen_random_uuid(),
          (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
          (SELECT id FROM providers WHERE type='lambda'),
          'qwen25-coder-32b-instruct',
          NOW(),
          NOW()
        ),
        (
          gen_random_uuid(),
          (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
          (SELECT id FROM providers WHERE type='groq'),
          'qwen-2.5-coder-32b',
          NOW(),
          NOW()
        ),
        (
          gen_random_uuid(),
          (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
          (SELECT id FROM providers WHERE type='hyperbolic'),
          'Qwen/Qwen2.5-Coder-32B-Instruct',
          NOW(),
          NOW()
        ),
        (
          gen_random_uuid(),
          (SELECT id FROM model_configs WHERE name='qwen25-coder-32b'),
          (SELECT id FROM providers WHERE type='together'),
          'Qwen/Qwen2.5-Coder-32B-Instruct',
          NOW(),
          NOW()
        ),
        (
          gen_random_uuid(),
          (SELECT id FROM model_configs WHERE name='llama-4-maverick-17b-128e'),
          (SELECT id FROM providers WHERE type='groq'),
          'meta-llama/llama-4-maverick-17b-128e-instruct',
          NOW(),
          NOW()
        );
    """, "")
  end
end
