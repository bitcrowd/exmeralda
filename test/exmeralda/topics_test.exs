defmodule Exmeralda.TopicsTest do
  use Exmeralda.DataCase

  alias Exmeralda.Topics
  alias Exmeralda.Topics.Ingestion

  def insert_ingested_library(_) do
    library = insert(:library, name: "ecto")
    ingestion = insert(:ingestion, library: library, state: :ready)
    insert_list(3, :chunk, ingestion: ingestion, library: library)
    %{ingested: library, ingested_library_ingestion: ingestion}
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

  describe "list_ingestions_for_library/2" do
    setup [:insert_ingested_library, :insert_chunkless_library]

    test "returns ingestions for a library with Flop support", %{
      ingested: library,
      ingested_library_ingestion: library_ingestion
    } do
      {:ok, {ingestions, meta}} = Topics.list_ingestions_for_library(library, %{})

      assert [ingestion] = ingestions
      assert ingestion.id == library_ingestion.id
      assert meta.total_count == 1
    end

    test "filters ingestions by state", %{
      ingested: library,
      ingested_library_ingestion: ready_ingestion
    } do
      _queued_ingestion = insert(:ingestion, library: library, state: :queued)

      {:ok, {ingestions, meta}} =
        Topics.list_ingestions_for_library(library, %{
          "filters" => [%{"field" => "state", "value" => "ready"}]
        })

      assert length(ingestions) == 1
      assert hd(ingestions).id == ready_ingestion.id
      assert meta.total_count == 1
    end

    test "supports pagination", %{
      chunkless: library
    } do
      insert_list(3, :ingestion, library: library)

      {:ok, {ingestions, meta}} =
        Topics.list_ingestions_for_library(library, %{"page_size" => "2"})

      assert length(ingestions) == 2
      assert meta.total_count == 3
      assert meta.total_pages == 2
    end
  end

  describe "get_ingestion_stats/1" do
    setup [:insert_ingested_library, :insert_chunkless_library]

    test "returns chunk statistics for an ingestion", %{
      ingested_library_ingestion: ingestion
    } do
      stats = Topics.get_ingestion_stats(ingestion)

      assert stats.chunks_total == 3
      assert stats.chunks_embedding == 3
      assert stats.chunks_type == [code: 3]
    end

    test "returns zero stats for ingestion with no chunks", %{chunkless: chunkless_library} do
      ingestion = insert(:ingestion, library: chunkless_library)

      stats = Topics.get_ingestion_stats(ingestion)

      assert stats.chunks_total == 0
      assert stats.chunks_embedding == 0
      assert stats.chunks_type == []
    end
  end

  describe "list_ingestion_chunks/2" do
    setup :insert_ingested_library

    test "returns chunks for an ingestion with Flop support", %{
      ingested_library_ingestion: ingestion
    } do
      {:ok, {chunks, meta}} = Topics.list_ingestion_chunks(ingestion, %{})

      assert length(chunks) == 3
      assert meta.total_count == 3
    end

    test "filters chunks by type", %{ingested_library_ingestion: ingestion} do
      {:ok, {chunks, meta}} =
        Topics.list_ingestion_chunks(ingestion, %{
          "filters" => [%{"field" => "type", "value" => "code"}]
        })

      assert length(chunks) == 3
      assert meta.total_count == 3
    end

    test "supports pagination", %{ingested_library_ingestion: ingestion} do
      {:ok, {chunks, meta}} = Topics.list_ingestion_chunks(ingestion, %{"page_size" => "2"})

      assert length(chunks) == 2
      assert meta.total_count == 3
      assert meta.total_pages == 2
    end
  end
end
