defmodule Exmeralda.Repo.Migrations.InsertIngestionsForLibrariesAndAssociateChunks do
  use Ecto.Migration
  import Ecto.Query

  def up do
    libraries_ids =
      repo().all(
        from l in "libraries",
          left_join: i in "ingestions",
          on: i.library_id == l.id,
          where: is_nil(i.library_id),
          select: l.id
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

    flush()

    execute("""
    UPDATE chunks
    SET ingestion_id = ingestions.id
    FROM
    ingestions
    WHERE
    chunks.ingestion_id IS NULL
    AND chunks.library_id = ingestions.library_id;
    """)
  end

  def down, do: :ok
end
