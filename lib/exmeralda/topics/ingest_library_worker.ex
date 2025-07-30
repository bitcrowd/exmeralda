defmodule Exmeralda.Topics.IngestLibraryWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20, unique: [period: {360, :minutes}]

  alias Exmeralda.Repo
  alias Exmeralda.Topics
  alias Exmeralda.Topics.{Chunk, Ingestion, Rag, GenerateEmbeddingsWorker}

  @insert_batch_size 1000

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ingestion_id" => ingestion_id}}) do
    ingestion = Repo.get!(Ingestion, ingestion_id, preload: :library)

    proceed_ingestion(ingestion)
  end

  def proceed_ingestion(ingestion) when ingestion.state in [:embedding, :ready, :failed] do
  end

  def proceed_ingestion(ingestion) do
    do_proceed_ingestion(ingestion)
    |> proceed_ingestion()
  end

  def do_proceed_ingestion(%{ingestion: %{state: :queued} = ingestion}) do
    %{ingestion: ingestion |> Topics.update_ingestion_state!(:preprocessing)}
  end

  def do_proceed_ingestion(%{ingestion: %{state: :preprocessing} = ingestion}) do
    library = ingestion.library

    with {:ok, code_docs_deps} <-
           Rag.get_code_and_docs_and_dependencies(library.name, library.version),
         {:ok, _library} <-
           Topics.update_library(library, %{dependencies: code_docs_deps.dependencies}) do
      ingestion =
        Topics.update_ingestion_state!(ingestion, :chunking)

      code_and_docs = Map.drop(code_docs_deps, :dependencies)

      %{ingestion: ingestion, args: code_and_docs}
    else
      _error -> {:discard, error}
    end
  end

  def do_proceed_ingestion(%{ingestion: %{state: :embedding} = ingestion}) do
    GenerateEmbeddingsWorker.new(%{library_id: ingestion.library_id, ingestion_id: ingestion.id})
  end

  def do_proceed_ingestion(%{state: :chunking} = ingestion, %{docs: docs, code: code}) do
    docs_chunks =
      for {file, content} <- docs, chunk <- Rag.chunk_text(file, content) do
        %{source: file, type: :docs, content: chunk}
      end

    code_chunks =
      for {file, content} <- code, chunk <- Rag.chunk_text(file, content) do
        %{source: file, type: :code, content: Enum.join(["# #{file}\n\n", chunk])}
      end

    (docs_chunks ++ code_chunks)
    |> Enum.map(&to_chunk(&1, ingestion))
    |> Enum.chunk_every(@insert_batch_size)
    |> Enum.each(&Repo.insert_all(Chunk, &1))

    Topics.update_ingestion_state!(ingestion, :embedding)
  end

  defp to_chunk(chunk, ingestion) do
    Map.merge(chunk, %{ingestion_id: ingestion.id, library_id: ingestion.library_id})
  end

  def ingest(multi) do
    multi
    |> Multi.run(:insert_ingestion, fn repo, %{library: library} ->
      repo.insert(Ingestion.changeset(%{state: :embedding, library_id: library.id}))
    end)
    |> Multi.run(:ingestion, fn _, %{library: library} ->
      Rag.ingest_from_hex(library.name, library.version)
    end)
    |> Multi.update(:dependencies, fn %{library: library, ingestion: {_, dependencies}} ->
      Library.changeset(library, %{dependencies: dependencies})
    end)
    |> Ecto.Multi.merge(fn %{
                             ingestion: {chunks, _},
                             insert_ingestion: ingestion,
                             library: library
                           } ->
      chunks
      |> Enum.chunk_every(@insert_batch_size)
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {batch, index}, multi ->
        Multi.insert_all(
          multi,
          :"chunks_#{index}",
          Chunk,
          Enum.map(batch, &Map.merge(&1, %{ingestion_id: ingestion.id, library_id: library.id}))
        )
      end)
    end)
    |> Oban.insert(:generate_embeddings, fn %{library: library, insert_ingestion: ingestion} ->
      GenerateEmbeddingsWorker.new(%{library_id: library.id, ingestion_id: ingestion.id})
    end)
    |> Repo.transaction(timeout: 1000 * 60 * 60)
    |> case do
      {:ok, _} -> :ok
      {:error, :library, error, _} -> 
      {:error, :ingestion, {:repo_not_found, _} = error, _} -> {:discard, error}
      {:error, step, error, changes} -> {:error, {step, error, changes}}
    end
  end
end
