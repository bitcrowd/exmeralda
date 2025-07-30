defmodule Exmeralda.Ingestions do
  alias Exmeralda.Repo
  alias Exmeralda.Topics
  alias Exmeralda.Topics.{Chunk, Rag, GenerateEmbeddingsWorker}

  @insert_batch_size 1000

  def set_preprocessing(%{state: :queued} = ingestion) do
    ingestion = Topics.update_ingestion_state!(ingestion, :preprocessing)
    {:ok, ingestion}
  end

  def set_chunking(%{state: :preprocessing} = ingestion) do
    library = ingestion.library

    with {:ok, code_docs_deps} <-
           Rag.get_code_and_docs_and_dependencies(library.name, library.version),
         {:ok, _library} <-
           Topics.update_library(library, %{dependencies: code_docs_deps.dependencies}) do
      ingestion =
        Topics.update_ingestion_state!(ingestion, :chunking)

      code_and_docs = Map.drop(code_docs_deps, [:dependencies])

      {:ok, %{ingestion: ingestion, args: code_and_docs}}
    end
  end

  def set_embedding(%{state: :chunking} = ingestion, %{docs: docs, code: code}) do
    docs_chunks =
      for %{source: file, content: content} <- docs, chunk <- Rag.chunk_text(file, content) do
        %{source: file, type: :docs, content: chunk}
      end

    code_chunks =
      for %{source: file, content: content} <- code, chunk <- Rag.chunk_text(file, content) do
        %{source: file, type: :code, content: Enum.join(["# #{file}\n\n", chunk])}
      end

    (docs_chunks ++ code_chunks)
    |> Enum.map(&to_chunk(&1, ingestion))
    |> Enum.chunk_every(@insert_batch_size)
    |> Enum.each(&Repo.insert_all(Chunk, &1))

    ingestion = Topics.update_ingestion_state!(ingestion, :embedding)
    {:ok, ingestion}
  end

  def schedule_embeddings_worker(%{state: :embedding} = ingestion) do
    GenerateEmbeddingsWorker.new(%{library_id: ingestion.library_id, ingestion_id: ingestion.id})
    |> Oban.insert()
  end

  defp to_chunk(chunk, ingestion) do
    Map.merge(chunk, %{ingestion_id: ingestion.id, library_id: ingestion.library_id})
  end
end
