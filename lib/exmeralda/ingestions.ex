defmodule Exmeralda.Ingestions do
  alias Exmeralda.Repo
  alias Exmeralda.Topics
  alias Exmeralda.Topics.{Chunk, Rag, GenerateEmbeddingsWorker}

  @insert_batch_size 1000

  def preprocess(%{state: :preprocessing} = ingestion) do
    library = ingestion.library

    with {:ok, {documents, dependencies}} <-
           Rag.get_documents_and_dependencies(library.name, library.version),
         {:ok, _library} <- Topics.update_library(library, %{dependencies: dependencies}) do
      {:ok, documents}
    end
  end

  def chunk_and_insert_documents(%{state: :chunking} = ingestion, documents) do
    chunks =
      for document <- documents,
          content_chunk <- Rag.chunk_text(document.source, document.content) do
        to_chunk(content_chunk, document, ingestion)
      end

    chunks
    |> Enum.chunk_every(@insert_batch_size)
    |> Enum.each(&Repo.insert_all(Chunk, &1))

    :ok
  end

  def schedule_embeddings_worker(%{state: :embedding} = ingestion) do
    GenerateEmbeddingsWorker.new(%{library_id: ingestion.library_id, ingestion_id: ingestion.id})
    |> Oban.insert()
  end

  defp to_chunk(content_chunk, document, ingestion) do
    content_chunk = maybe_insert_header(content_chunk, document)

    %{
      source: document.source,
      type: document.type,
      content: content_chunk,
      ingestion_id: ingestion.id,
      library_id: ingestion.library_id
    }
  end

  defp maybe_insert_header(content, %{type: :code} = document) do
    """
    # #{document.source}

    #{content}
    """
  end

  defp maybe_insert_header(content, _document), do: content
end
