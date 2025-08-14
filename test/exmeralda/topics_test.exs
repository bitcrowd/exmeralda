defmodule Exmeralda.TopicsTest do
  use Exmeralda.DataCase

  alias Exmeralda.Topics
  alias Exmeralda.Topics.{Ingestion, Library}

  def insert_library(_) do
    %{library: insert(:library)}
  end

  def insert_ingested_library(_) do
    library = insert(:library, name: "ecto")
    ingestion = insert(:ingestion, library: library, state: :ready)
    insert_list(3, :chunk, ingestion: ingestion, library: library)
    %{ingested: library, ingested_library_ingestion: ingestion}
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
    test "updates state of ingestion and broadcasts state updated" do
      Phoenix.PubSub.subscribe(Exmeralda.PubSub, "ingestions")

      ingestion = insert(:ingestion, state: :queued)

      assert %Ingestion{id: ingestion_id} = Topics.update_ingestion_state!(ingestion, :embedding)

      ingestion = Repo.reload(ingestion)

      assert ingestion.state == :embedding

      assert_receive {:ingestion_state_updated, %{id: ^ingestion_id}}
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

  describe "list_ingestions/2" do
    setup [:insert_ingested_library, :insert_chunkless_library]

    test "returns ingestions for a library with Flop support", %{
      ingested: library,
      ingested_library_ingestion: library_ingestion
    } do
      {:ok, {ingestions, meta}} = Topics.list_ingestions(library, %{})

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
        Topics.list_ingestions(library, %{
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

      {:ok, {ingestions, meta}} = Topics.list_ingestions(library, %{"page_size" => "2"})

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

  describe "create_library/1" do
    test "creates a library and an ingestion, starts worker and broadcasts ingestion created" do
      Phoenix.PubSub.subscribe(Exmeralda.PubSub, "ingestions")

      params = %{name: "ecto", version: "1.0.0"}

      assert_count_differences(Repo, [{Library, 1}, {Ingestion, 1}], fn ->
        assert {:ok, %{library: library, ingestion: ingestion}} = Topics.create_library(params)

        assert %{name: "ecto", version: "1.0.0", dependencies: []} = library
        assert ingestion.library_id == library.id
        assert ingestion.state == :queued
        assert ingestion.job_id
      end)

      [%{id: ingestion_id, job_id: job_id}] = Repo.all(Ingestion)

      assert_enqueued(
        id: job_id,
        worker: Exmeralda.Topics.IngestLibraryWorker,
        args: %{ingestion_id: ingestion_id}
      )

      assert_receive {:ingestion_created, %{id: ^ingestion_id}}
    end

    test "returns a changeset when the params are invalid" do
      assert {:error, %Ecto.Changeset{}} = Topics.create_library(%{})
    end
  end

  describe "reingest_library/1" do
    test "errors if the library is not found" do
      assert Topics.reingest_library(uuid()) == {:error, {:not_found, Library}}
    end

    test "creates an ingestion, starts worker and broadcasts ingestion created" do
      Phoenix.PubSub.subscribe(Exmeralda.PubSub, "ingestions")

      library = insert(:library)

      assert_count_differences(Repo, [{Library, 0}, {Ingestion, 1}], fn ->
        assert {:ok, ingestion} = Topics.reingest_library(library.id)

        assert ingestion.library_id == library.id
        assert ingestion.state == :queued
        assert ingestion.job_id
      end)

      [%{id: ingestion_id, job_id: job_id}] = Repo.all(Ingestion)

      assert_enqueued(
        id: job_id,
        worker: Exmeralda.Topics.IngestLibraryWorker,
        args: %{ingestion_id: ingestion_id}
      )

      assert_receive {:ingestion_created, %{id: ^ingestion_id}}
    end
  end
end
