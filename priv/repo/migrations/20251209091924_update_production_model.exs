defmodule Exmeralda.Repo.Migrations.UpdateProductionModel do
  use Ecto.Migration

  def change do
    unless Mix.env() == :test do
      execute(
        """
        INSERT INTO model_configs (id, name, config, inserted_at, updated_at)
        VALUES (gen_random_uuid(), 'qwen25-7b-instruct-turbo', '{"stream": true}', NOW(), NOW());
        """,
        """
        DELETE FROM model_configs
        WHERE name = 'qwen25-7b-instruct-turbo';
        """
      )

      execute(
        """
        INSERT INTO model_config_providers (id, model_config_id, provider_id, name, inserted_at, updated_at)
        VALUES (
                 gen_random_uuid(),
                 (SELECT id FROM model_configs WHERE name='qwen25-7b-instruct-turbo'),
                 (SELECT id FROM providers WHERE name='together_ai'),
                 'Qwen/Qwen2.5-7B-Instruct-Turbo',
                 NOW(),
                 NOW()
        );
        """,
        """
        DELETE FROM model_config_providers
        WHERE name = 'Qwen/Qwen2.5-7B-Instruct-Turbo';
        """
      )
    end
  end
end
