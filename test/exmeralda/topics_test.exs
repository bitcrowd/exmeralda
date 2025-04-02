defmodule Exmeralda.TopicsTest do
  use Exmeralda.DataCase

  alias Exmeralda.Topics
  alias Exmeralda.Topics.Chunk

  def insert_ingested_library(_) do
    library = insert(:library, name: "ecto")
    insert_list(3, :chunk, library: library)
    %{ingested: library}
  end

  def insert_in_progress_library(_) do
    library = insert(:library, name: "ecto_sql")
    insert_list(3, :chunk, library: library)
    insert_list(1, :chunk, library: library, embedding: nil)
    %{in_progress: library}
  end

  def insert_chunkless_library(_) do
    library = insert(:library, name: "bitcrowd_ecto")
    %{chunkless: library}
  end

  describe "search_libraries/1" do
    setup [:insert_ingested_library, :insert_chunkless_library, :insert_in_progress_library]

    test "returns only libraries that are ingested fully and match the term", %{
      ingested: ingested,
      chunkless: chunkless,
      in_progress: in_progress
    } do
      ids = Topics.search_libraries("ecto") |> Enum.map(& &1.id)
      assert ingested.id in ids
      assert chunkless.id in ids
      refute in_progress.id in ids

      from(c in Chunk, where: is_nil(c.embedding)) |> Exmeralda.Repo.delete_all()

      ids = Topics.search_libraries("ecto") |> Enum.map(& &1.id)
      assert in_progress.id in ids
    end
  end
end
