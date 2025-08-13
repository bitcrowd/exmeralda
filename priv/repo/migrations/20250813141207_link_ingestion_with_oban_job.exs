defmodule Exmeralda.Repo.Migrations.LinkIngestionWithObanJob do
  use Ecto.Migration

  def change do
    alter table(:ingestions) do
      add :job_id, references(:oban_jobs, on_delete: :nilify_all, type: :bigint), null: true
    end
  end
end
