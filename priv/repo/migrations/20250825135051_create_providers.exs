defmodule Exmeralda.Repo.Migrations.CreateProviders do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE provider_type AS ENUM ('lambda', 'groq', 'hyperbolic', 'together', 'mock');",
      "DROP TYPE provider_type;"
    )

    create table(:providers) do
      add :type, :provider_type, null: false
      add :endpoint, :string, null: false

      timestamps()
    end
  end
end
