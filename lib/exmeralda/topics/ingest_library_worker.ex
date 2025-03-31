defmodule Exmeralda.Topics.IngestLibraryWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20, unique: [period: {360, :minutes}]

  alias Exmeralda.Repo
  alias Exmeralda.Topics.{Chunk, Library, Rag}

  alias Ecto.Multi

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Multi.new()
    |> Multi.insert(:library, Library.changeset(%Library{}, args))
    |> Multi.run(:ingestion, fn _, %{library: library} ->
      Rag.ingest_from_hex(library.name, library.version)
    end)
    |> Multi.update(:dependencies, fn %{library: library, ingestion: {_, dependencies}} ->
      Library.changeset(library, %{dependencies: dependencies})
    end)
    |> Multi.insert_all(:chunks, Chunk, fn %{library: library, ingestion: {chunks, _}} ->
      Enum.map(chunks, &Map.put(&1, :library_id, library.id))
    end)
    |> Repo.transaction(timeout: 100_000)
    |> case do
      {:ok, _} -> :ok
      {:error, :ingestion, {:repo_not_found, _} = error, _} -> {:discard, error}
      {:error, step, error, changes} -> {:error, {step, error, changes}}
    end
  end
end
