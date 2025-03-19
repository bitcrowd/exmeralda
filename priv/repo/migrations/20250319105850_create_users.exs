defmodule Exmeralda.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :text, null: false
      add :email, :string, null: false, size: 320
      add :github_id, :string, null: false
      add :github_profile, :text, null: false
      add :avatar_url, :text, null: false

      timestamps()
    end

    create unique_index(:users, :github_id)
  end
end
