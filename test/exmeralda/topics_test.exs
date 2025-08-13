defmodule Exmeralda.TopicsTest do
  use Exmeralda.DataCase

  alias Exmeralda.Topics
  alias Exmeralda.Topics.Ingestion

  def insert_library(_) do
    %{library: insert(:library)}
  end

  def insert_ingested_library(_) do
    library = insert(:library, name: "ecto")
    ingestion = insert(:ingestion, library: library, state: :ready)
    insert_list(3, :chunk, ingestion: ingestion, library: library)
    %{ingested: library}
  end

  def insert_in_progress_library(_) do
    library = insert(:library)
    ingestion = insert(:ingestion, library: library, state: :embedding)
    insert_list(3, :chunk, ingestion: ingestion, library: library)
    insert_list(1, :chunk, ingestion: ingestion, library: library, embedding: nil)
    %{in_progress: library, in_progress_ingestion: ingestion}
  end

  def insert_chunkless_library(_) do
    library = insert(:library)
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
      in_progress: in_progress
    } do
      ids = Topics.search_libraries("ecto") |> Enum.map(& &1.id)
      assert ingested.id in ids
      refute chunkless.id in ids
      refute in_progress.id in ids
    end
  end

  describe "update_ingestion_state!/2" do
    test "updates state of ingestion" do
      ingestion = insert(:ingestion, state: :queued)

      assert %Ingestion{} = Topics.update_ingestion_state!(ingestion, :embedding)

      ingestion = Repo.reload(ingestion)

      assert ingestion.state == :embedding
    end
  end

  describe "current_ingestion/1" do
    setup [:insert_library]

    test "returns nil when no ingestion", %{library: library} do
      refute Topics.current_ingestion(library)
    end

    test "returns the latest ingestion in state :ready for a library", %{library: library} do
      insert(:ingestion, library: library, state: :queued)
      _other_library_ingestion = insert(:ingestion, library: insert(:library), state: :ready)
      new_ready_ingestion = insert(:ingestion, library: library, state: :ready)

      _old_ready_ingestion =
        insert(:ingestion,
          library: library,
          state: :ready,
          inserted_at: DateTime.add(DateTime.utc_now(), -10)
        )

      assert Topics.current_ingestion(library).id == new_ready_ingestion.id
    end
  end
end
