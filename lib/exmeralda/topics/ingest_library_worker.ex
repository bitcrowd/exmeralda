defmodule Exmeralda.Topics.IngestLibraryWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20, unique: [period: {360, :minutes}]

  alias Exmeralda.Repo
  alias Exmeralda.Topics
  alias Exmeralda.Topics.{Chunk, Ingestion, Library, Rag, GenerateEmbeddingsWorker}

  @insert_batch_size 1000

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ingestion_id" => ingestion_id}}) do
    Repo.transact(fn ->
      with {:ok, ingestion} <- fetch_ingestion(ingestion_id),
           # TODO: Fetching the dependencies is redundant, we should do it once only
           # when we create the library. The new worker should then enqueue this one.
           {:ok, {chunks, dependencies}} <- get_chunks_and_dependencies(ingestion),
           {:ok, _library} <- update_library(ingestion.library, dependencies),
           :ok <- create_chunks(ingestion, chunks),
           {:ok, job} <- schedule_embeddings_worker(ingestion),
           {:ok, updated_ingestion} <- Topics.set_ingestion_job_id(ingestion, job) do
        {:ok, Topics.update_ingestion_state!(updated_ingestion, :embedding)}
      end
    end)
    |> case do
      {:error, :ingestion_not_found} ->
        {:cancel, :ingestion_not_found}

      {:error, {:ingestion_in_invalid_state, state}} ->
        {:cancel, {:ingestion_in_invalid_state, state}}

      {:error, {:repo_not_found, url, ingestion}} ->
        # TODO: we should probably persist the error on the ingestion...
        Topics.update_ingestion_state!(ingestion, :failed)
        {:discard, {:repo_not_found, url}}

      {:ok, _} ->
        :ok

      other ->
        other
    end
  end

  defp fetch_ingestion(ingestion_id) do
    case Repo.get(Ingestion, ingestion_id) do
      nil -> {:error, :ingestion_not_found}
      %{state: :queued} = ingestion -> {:ok, Repo.preload(ingestion, [:library])}
      %{state: state} -> {:error, {:ingestion_in_invalid_state, state}}
    end
  end

  defp get_chunks_and_dependencies(ingestion) do
    case Rag.ingest_from_hex(ingestion.library.name, ingestion.library.version) do
      {:error, {:repo_not_found, url}} ->
        {:error, {:repo_not_found, url, ingestion}}

      other ->
        other
    end
  end

  defp update_library(library, dependencies) do
    library
    |> Library.set_dependencies_changeset(dependencies)
    |> Repo.update()
  end

  defp schedule_embeddings_worker(ingestion) do
    GenerateEmbeddingsWorker.new(%{library_id: ingestion.library_id, ingestion_id: ingestion.id})
    |> Oban.insert()
  end

  defp create_chunks(ingestion, chunks) do
    chunks
    |> Enum.chunk_every(@insert_batch_size)
    |> Enum.each(fn batch ->
      batch =
        Enum.map(
          batch,
          &Map.merge(&1, %{ingestion_id: ingestion.id, library_id: ingestion.library_id})
        )

      Repo.insert_all(Chunk, batch)
    end)

    :ok
  end

  # @impl Oban.Worker
  # def perform(%Oban.Job{args: %{"library_id" => library_id}}) do
  #   chunks = from c in Chunk, where: c.library_id == ^library_id

  #   Multi.new()
  #   |> Multi.delete_all(:remove_chunks, chunks)
  #   |> Multi.run(:library, fn repo, _ -> {:ok, repo.get!(Library, library_id)} end)
  #   |> ingest()
  # end

  # def ingest(multi) do
  #   multi
  #   |> Multi.run(:insert_ingestion, fn repo, %{library: library} ->
  #     repo.insert(Ingestion.changeset(%{state: :embedding, library_id: library.id}))
  #   end)
  #   |> Multi.run(:ingestion, fn _, %{library: library} ->
  #     Rag.ingest_from_hex(library.name, library.version)
  #   end)
  #   |> Multi.update(:dependencies, fn %{library: library, ingestion: {_, dependencies}} ->
  #     Library.changeset(library, %{dependencies: dependencies})
  #   end)
  #   |> Ecto.Multi.merge(fn %{
  #                            ingestion: {chunks, _},
  #                            insert_ingestion: ingestion,
  #                            library: library
  #                          } ->
  #     chunks
  #     |> Enum.chunk_every(@insert_batch_size)
  #     |> Enum.with_index()
  #     |> Enum.reduce(Multi.new(), fn {batch, index}, multi ->
  #       Multi.insert_all(
  #         multi,
  #         :"chunks_#{index}",
  #         Chunk,
  #         Enum.map(batch, &Map.merge(&1, %{ingestion_id: ingestion.id, library_id: library.id}))
  #       )
  #     end)
  #   end)
  #   |> Oban.insert(:generate_embeddings, fn %{library: library, insert_ingestion: ingestion} ->
  #     GenerateEmbeddingsWorker.new(%{library_id: library.id, ingestion_id: ingestion.id})
  #   end)
  #   |> Repo.transaction(timeout: 1000 * 60 * 60)
  #   |> case do
  #     {:ok, _} -> :ok
  #     {:error, :library, error, _} -> {:discard, error}
  #     {:error, :ingestion, {:repo_not_found, _} = error, _} -> {:discard, error}
  #     {:error, step, error, changes} -> {:error, {step, error, changes}}
  #   end
  # end
end
