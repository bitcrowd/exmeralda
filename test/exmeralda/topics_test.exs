defmodule Exmeralda.TopicsTest do
  use Exmeralda.DataCase

  alias Exmeralda.Topics
  alias Exmeralda.Topics.Ingestion

  def insert_ingested_library(_) do
    library = insert(:library, name: "ecto")
    ingestion = insert(:ingestion, library: library, state: :ready)
    insert_list(3, :chunk, ingestion: ingestion, library: library)
    %{ingested: library}
  end

  def insert_in_progress_library(_) do
    library = insert(:library, name: "ecto_sql")
    ingestion = insert(:ingestion, library: library, state: :embedding)
    insert_list(3, :chunk, ingestion: ingestion, library: library)
    insert_list(1, :chunk, ingestion: ingestion, library: library, embedding: nil)
    %{in_progress: library, in_progress_ingestion: ingestion}
  end

  def insert_chunkless_library(_) do
    library = insert(:library, name: "bitcrowd_ecto")
    %{chunkless: library}
  end

  describe "last_libraries/0" do
    setup [:insert_ingested_library, :insert_chunkless_library, :insert_in_progress_library]

    test "returns only libraries with ingestion that is ready", %{
      ingested: ingested,
      chunkless: chunkless,
      in_progress: in_progress
    } do
      ids = Topics.last_libraries() |> Enum.map(& &1.id)

      assert ingested.id in ids
      refute in_progress.id in ids
      refute chunkless.id in ids
    end
  end

  describe "search_libraries/1" do
    setup [:insert_ingested_library, :insert_chunkless_library, :insert_in_progress_library]

    test "returns only libraries that are ingested fully and match the term", %{
      ingested: ingested,
      chunkless: chunkless,
      in_progress: in_progress,
      in_progress_ingestion: in_progress_ingestion
    } do
      ids = Topics.search_libraries("ecto") |> Enum.map(& &1.id)
      assert ingested.id in ids
      refute chunkless.id in ids
      refute in_progress.id in ids

      Ingestion.set_state(in_progress_ingestion, :ready) |> Repo.update!()

      ids = Topics.search_libraries("ecto") |> Enum.map(& &1.id)
      assert in_progress.id in ids
    end
  end

  describe "update_ingestion_state!/2" do
    test "updates state of ingestion" do
      ingestion = insert(:ingestion, state: :queued)

      Topics.update_ingestion_state!(ingestion, :embedding)

      ingestion = Repo.reload(ingestion)

      assert ingestion.state == :embedding
    end
  end

  describe "current_ingestion/1" do
    test "returns nil when no ingestion" do
      library = insert(:library)

      refute Topics.current_ingestion(library)
    end

    test "returns the latest ingestion in state :ready for a library" do
      library = insert(:library)
      queued_ingestion = insert(:ingestion, library: library)

      refute Topics.current_ingestion(library)

      ready_ingestion = Ingestion.set_state(queued_ingestion, :ready) |> Repo.update!()

      assert Topics.current_ingestion(library).id == ready_ingestion.id

      _non_ready_ingestion = insert(:ingestion, library: library)

      assert Topics.current_ingestion(library).id == ready_ingestion.id

      new_ready_ingestion = insert(:ingestion, library: library, state: :ready)

      assert Topics.current_ingestion(library).id == new_ready_ingestion.id
    end
  end
end
