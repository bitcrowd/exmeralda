defmodule Exmeralda.Repo.Migrations.AddActiveToIngestions do
  use Ecto.Migration

  def up do
    alter table(:ingestions) do
      add :active, :boolean, default: false, null: false
    end

    execute("""
      UPDATE ingestions
      SET active = TRUE
      FROM (
        SELECT DISTINCT ON (library_id) *
        FROM ingestions
        WHERE state = 'ready'
        ORDER BY library_id, inserted_at DESC
      ) AS subquery
      WHERE ingestions.id = subquery.id;
    """)

    create unique_index(:ingestions, [:library_id, :active], where: "active IS TRUE")

    create(
      constraint(
        :ingestions,
        :active_when_ready,
        check: "NOT (active IS TRUE AND state != 'ready')"
      )
    )
  end

  def down do
    alter table(:ingestions) do
      remove :active
    end
  end
end
