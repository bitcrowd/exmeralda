defmodule Exmeralda.Repo.Migrations.CreateProviders do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE provider_type AS ENUM ('lambda', 'groq', 'hyperbolic', 'together');",
      "DROP TYPE provider_type;"
    )

    create table(:providers) do
      add :type, :provider_type, null: false
      add :endpoint, :string, null: false

      timestamps()
    end

    create unique_index(:providers, [:type])

    execute("""
      INSERT INTO providers (id, type, endpoint, inserted_at, updated_at)
      VALUES
        (gen_random_uuid(), 'lambda', 'https://api.lambda.ai/v1/chat/completions', NOW(), NOW()),
        (gen_random_uuid(), 'groq', 'https://api.groq.com/openai/v1/chat/completions', NOW(), NOW()),
        (gen_random_uuid(), 'hyperbolic', 'https://api.hyperbolic.xyz/v1/chat/completions', NOW(), NOW()),
        (gen_random_uuid(), 'together', 'https://api.together.xyz/v1/chat/completions', NOW(), NOW());
    """, "")
  end
end
