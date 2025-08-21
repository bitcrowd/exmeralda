defmodule Exmeralda.TopicsTest do
  use Exmeralda.DataCase

  alias Exmeralda.Topics
  alias Exmeralda.Topics.{Ingestion, Library}

  def insert_user(_) do
    %{user: insert(:user)}
  end

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

      assert_receive {:ingestion_state_updated, %{id: ^ingestion_id} = ingestion}
      assert_preloaded(ingestion, [:job])
    end
  end

  describe "active_ingestion/1" do
    setup [:insert_library]

    test "returns an error when no ingestion at all", %{library: library} do
      assert Topics.active_ingestion(library.id) == {:error, {:not_found, Ingestion}}
    end

    test "returns an error when no active ingestion exist", %{library: library} do
      insert(:ingestion, state: :ready, active: false, library: library)
      assert Topics.active_ingestion(library.id) == {:error, {:not_found, Ingestion}}
    end

    test "returns the active ingestion if present", %{library: library} do
      active_ingestion = insert(:ingestion, state: :ready, active: true, library: library)

      _other_library_ingestion =
        insert(:ingestion, library: insert(:library), active: true, state: :ready)

      _other_ingestion = insert(:ingestion, library: library, active: false)

      assert {:ok, ingestion} = Topics.active_ingestion(library.id)
      assert ingestion.id == active_ingestion.id
    end
  end

  describe "list_ingestions/2" do
    setup [:insert_ingested_library]

    test "returns all ingestions with Flop support", %{
      ingested: library,
      ingested_library_ingestion: library_ingestion
    } do
      _other_library_ingestion = insert(:ingestion)
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

    test "supports pagination", %{ingested: library} do
      insert_list(3, :ingestion, library: library)

      {:ok, {ingestions, meta}} =
        Topics.list_ingestions(library, %{"page_size" => "2"})

      assert length(ingestions) == 2
      assert meta.total_count == 4
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

  describe "list_chunks_for_ingestion/2" do
    setup :insert_ingested_library

    test "returns chunks for an ingestion with Flop support", %{
      ingested_library_ingestion: ingestion
    } do
      {:ok, {chunks, meta}} = Topics.list_chunks_for_ingestion(ingestion, %{})

      assert length(chunks) == 3
      assert meta.total_count == 3
    end

    test "filters chunks by type", %{ingested_library_ingestion: ingestion} do
      {:ok, {chunks, meta}} =
        Topics.list_chunks_for_ingestion(ingestion, %{
          "filters" => [%{"field" => "type", "value" => "code"}]
        })

      assert length(chunks) == 3
      assert meta.total_count == 3
    end

    test "supports pagination", %{ingested_library_ingestion: ingestion} do
      {:ok, {chunks, meta}} = Topics.list_chunks_for_ingestion(ingestion, %{"page_size" => "2"})

      assert length(chunks) == 2
      assert meta.total_count == 3
      assert meta.total_pages == 2
    end
  end

  describe "create_library/2" do
    setup [:insert_user]

    test "creates a library and an ingestion, starts ingestion worker, broadcasts ingestion created and notifies the user",
         %{user: user} do
      Phoenix.PubSub.subscribe(Exmeralda.PubSub, "ingestions")

      params = %{name: "ecto", version: "1.0.0"}

      assert_count_differences(Repo, [{Library, 1}, {Ingestion, 1}], fn ->
        assert {:ok, %{library: library, ingestion: ingestion}} =
                 Topics.create_library(user, params)

        assert %{name: "ecto", version: "1.0.0", dependencies: []} = library
        assert ingestion.library_id == library.id
        assert ingestion.state == :queued
        assert ingestion.job_id
      end)

      [%{id: ingestion_id, library_id: library_id, job_id: job_id}] = Repo.all(Ingestion)

      assert_enqueued(
        id: job_id,
        worker: Exmeralda.Topics.IngestLibraryWorker,
        args: %{ingestion_id: ingestion_id}
      )

      assert_enqueued(
        worker: Exmeralda.Topics.DeliverIngestionInProgressEmailWorker,
        args: %{user_id: user.id, library_id: library_id}
      )

      assert_receive {:ingestion_created, %{id: ^ingestion_id}}
    end

    test "returns a changeset when the params are invalid", %{user: user} do
      assert {:error, %Ecto.Changeset{}} = Topics.create_library(user, %{})

      refute_enqueued(worker: Exmeralda.Topics.IngestLibraryWorker)
      refute_enqueued(worker: Exmeralda.Topics.DeliverIngestionInProgressEmailWorker)
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

  describe "last_ingestions/1" do
    test "returns the last 10 ingestions in the given states" do
      library = insert(:library)
      insert_list(10, :ingestion, library: library, state: :ready)
      insert(:ingestion, library: library, state: :failed)

      result = Topics.last_ingestions([:ready])
      assert length(result) == 10
      assert Enum.all?(result, &(&1.state == :ready))
    end
  end

  describe "delete_ingestion/1 when the ingestion does not exist" do
    test "returns ok" do
      assert Topics.delete_ingestion(uuid()) == {:ok, :ok}
    end
  end

  for state <- [:queued, :embedding] do
    describe "delete_ingestion/1 when the ingestion state is #{state}" do
      test "returns an error" do
        ingestion = insert(:ingestion, state: unquote(state))
        assert Topics.delete_ingestion(ingestion.id) == {:error, :ingestion_invalid_state}
      end
    end
  end

  describe "delete_ingestion/1" do
    setup do
      %{ingestion: insert(:ingestion, state: :ready)}
    end

    test "returns an error when the ingestion has existing chat sessions", %{ingestion: ingestion} do
      insert(:chat_session, ingestion: ingestion)
      assert Topics.delete_ingestion(ingestion.id) == {:error, :ingestion_has_chats}
    end

    test "deletes the ingestion", %{ingestion: ingestion} do
      assert {:ok, _} = Topics.delete_ingestion(ingestion.id)
      refute Repo.reload(ingestion)
    end
  end

  describe "delete_library/1 when the library does not exist" do
    test "returns ok" do
      assert Topics.delete_library(uuid()) == {:ok, :ok}
    end
  end

  describe "delete_library/1" do
    setup do
      %{library: insert(:library)}
    end

    test "returns an error when the library has existing chat sessions", %{library: library} do
      ingestion = insert(:ingestion, library: library)
      insert(:chat_session, ingestion: ingestion)
      assert Topics.delete_library(library.id) == {:error, :library_has_chats}
    end

    test "deletes the library, and its ingestions and chunks", %{library: library} do
      ingestion = insert(:ingestion, library: library)
      chunk = insert(:chunk, ingestion: ingestion)

      assert {:ok, _} = Topics.delete_library(library.id)
      refute Repo.reload(library)
      refute Repo.reload(ingestion)
      refute Repo.reload(chunk)
    end
  end

  describe "mark_ingestion_as_active/1 when the ingestion does not exist" do
    test "returns an error" do
      assert Topics.mark_ingestion_as_active(uuid()) == {:error, {:not_found, Ingestion}}
    end
  end

  for state <- [:queued, :embedding, :failed] do
    describe "mark_ingestion_as_active/1 when the ingestion is in state #{state}" do
      test "returns an error" do
        ingestion = insert(:ingestion, active: false, state: unquote(state))
        assert Topics.mark_ingestion_as_active(ingestion.id) == {:error, :ingestion_invalid_state}
      end
    end
  end

  describe "mark_ingestion_as_active/1 when the ingestion is already active" do
    test "returns an error" do
      ingestion = insert(:ingestion, active: true, state: :ready)
      assert Topics.mark_ingestion_as_active(ingestion.id) == {:error, :ingestion_already_active}
    end
  end

  describe "mark_ingestion_as_active/1" do
    test "marks the ingestion as active" do
      ingestion = insert(:ingestion, active: false, state: :ready)
      assert {:ok, %Ingestion{}} = Topics.mark_ingestion_as_active(ingestion.id)
      assert Repo.reload(ingestion).active
    end

    test "unmarks existing active ingestion" do
      library = insert(:library)
      ingestion = insert(:ingestion, active: false, state: :ready, library: library)
      active_ingestion = insert(:ingestion, active: true, state: :ready, library: library)
      _other_library = insert(:ingestion, active: true, state: :ready)

      assert {:ok, %Ingestion{}} = Topics.mark_ingestion_as_active(ingestion.id)
      assert Repo.reload(ingestion).active
      refute Repo.reload(active_ingestion).active
    end
  end

  describe "mark_ingestion_as_inactive/1 when the ingestion does not exist" do
    test "returns an error" do
      assert Topics.mark_ingestion_as_inactive(uuid()) == {:error, {:not_found, Ingestion}}
    end
  end

  for state <- [:queued, :embedding, :failed] do
    describe "mark_ingestion_as_inactive/1 when the ingestion is in state #{state}" do
      test "returns an error" do
        ingestion = insert(:ingestion, active: false, state: unquote(state))

        assert Topics.mark_ingestion_as_inactive(ingestion.id) ==
                 {:error, :ingestion_invalid_state}
      end
    end
  end

  describe "mark_ingestion_as_inactive/1 when the ingestion is already inactive" do
    test "returns an error" do
      ingestion = insert(:ingestion, active: false, state: :ready)

      assert Topics.mark_ingestion_as_inactive(ingestion.id) ==
               {:error, :ingestion_already_inactive}
    end
  end

  describe "mark_ingestion_as_inactive/1" do
    test "marks the ingestion as inactive" do
      library = insert(:library)
      ingestion = insert(:ingestion, active: false, state: :ready, library: library)
      active_ingestion = insert(:ingestion, active: true, state: :ready, library: library)
      _other_library = insert(:ingestion, active: false, state: :ready)

      assert {:ok, %Ingestion{}} = Topics.mark_ingestion_as_inactive(active_ingestion.id)
      refute Repo.reload(ingestion).active
      refute Repo.reload(active_ingestion).active
    end
  end
end
