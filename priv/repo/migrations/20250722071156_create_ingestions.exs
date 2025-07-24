defmodule Exmeralda.Repo.Migrations.CreateIngestions do
  use Ecto.Migration

  import Ecto.Query

  def up do
    execute(
      "CREATE TYPE ingestion_state AS ENUM ('queued', 'preprocessing', 'chunking', 'embedding', 'failed', 'ready');"
    )

    create table(:ingestions) do
      add :state, :ingestion_state, null: false
      add :library_id, references(:libraries, on_delete: :delete_all), null: false

      timestamps()
    end

    flush()

    libraries_ids =
      repo().all(
        from(l in "libraries",
          left_join: i in "ingestions",
          on: i.library_id == l.id,
          where: is_nil(i.library_id),
          select: l.id
        )
      )

    ingestions =
      Enum.map(libraries_ids, fn library_id ->
        %{
          id: Ecto.UUID.bingenerate(),
          state: "ready",
          library_id: library_id,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)

    repo().insert_all("ingestions", ingestions)
  end

  def down do
    drop table(:ingestions)

    execute("DROP TYPE ingestion_state;")
  end
end
