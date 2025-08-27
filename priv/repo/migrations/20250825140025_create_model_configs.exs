defmodule Exmeralda.Repo.Migrations.CreateModelConfigs do
  use Ecto.Migration

  def change do
    create table(:model_configs) do
      add :name, :string, null: false
      add :config, :map, null: false, default: %{}

      timestamps()
    end
  end
end
