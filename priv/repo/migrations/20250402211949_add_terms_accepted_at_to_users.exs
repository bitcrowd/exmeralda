defmodule Exmeralda.Repo.Migrations.AddTermsAcceptedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :terms_accepted_at, :utc_datetime_usec, null: true
    end
  end
end
