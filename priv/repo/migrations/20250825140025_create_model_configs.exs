defmodule Exmeralda.Repo.Migrations.CreateModelConfigs do
  use Ecto.Migration

  def change do
    create table(:model_configs) do
      add :name, :string, null: false
      add :config, :jsonb, null: false, default: "{}"

      timestamps()
    end

    execute("""
      INSERT INTO model_configs (id, name, config, inserted_at, updated_at)
      VALUES
        (gen_random_uuid(), 'qwen25-coder-32b', '{"stream": true}', NOW(), NOW()),
        (gen_random_uuid(), 'llama-4-maverick-17b-128e', '{"stream": true}', NOW(), NOW());
    """, "")
  end
end
