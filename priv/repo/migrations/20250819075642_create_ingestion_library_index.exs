defmodule Exmeralda.Repo.Migrations.CreateIngestionLibraryIndex do
  use Ecto.Migration

  def change do
    create index("ingestions", [:library_id])
  end
end
