defmodule Exmeralda.Topics.IngestLibraryWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20, unique: [period: {360, :minutes}]

  alias Exmeralda.Repo
  alias Exmeralda.Topics.{Chunk, Library, Rag, GenerateEmbeddingsWorker}
  alias Ecto.Multi
  import Ecto.Query

  @insert_batch_size 1000

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"library_id" => library_id}}) do
    chunks = from c in Chunk, where: c.library_id == ^library_id

    Multi.new()
    |> Multi.delete_all(:remove_chunks, chunks)
    |> Multi.run(:library, fn repo, _ -> {:ok, repo.get!(Library, library_id)} end)
    |> ingest()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Multi.new()
    |> Multi.insert(:library, Library.changeset(%Library{}, args))
    |> ingest()
  end

  def ingest(multi) do
    multi
    |> Multi.run(:ingestion, fn _, %{library: library} ->
      Rag.ingest_from_hex(library.name, library.version)
    end)
    |> Multi.update(:dependencies, fn %{library: library, ingestion: {_, dependencies}} ->
      Library.changeset(library, %{dependencies: dependencies})
    end)
    |> Ecto.Multi.merge(fn %{ingestion: {chunks, _}, library: library} ->
      chunks
      |> Enum.chunk_every(@insert_batch_size)
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {batch, index}, multi ->
        Multi.insert_all(
          multi,
          :"chunks_#{index}",
          Chunk,
          Enum.map(batch, &Map.put(&1, :library_id, library.id))
        )
      end)
    end)
    |> Oban.insert(:generate_embeddings, fn %{library: library} ->
      GenerateEmbeddingsWorker.new(%{library_id: library.id})
    end)
    |> Repo.transaction(timeout: 100_000)
    |> case do
      {:ok, _} -> :ok
      {:error, :library, error, _} -> {:discard, error}
      {:error, :ingestion, {:repo_not_found, _} = error, _} -> {:discard, error}
      {:error, step, error, changes} -> {:error, {step, error, changes}}
    end
  end
end
