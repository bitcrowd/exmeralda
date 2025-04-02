defmodule Exmeralda.Repo.Migrations.AllowLazyEmbedding do
  use Ecto.Migration

  def change do
    alter table(:chunks) do
      modify :embedding, :vector, size: 768, null: true, from: :vector
    end
  end
end
