defmodule Exmeralda.Topics.Rag do
  @moduledoc false
  alias Exmeralda.Repo
  alias Exmeralda.Topics.Chunk
  import Ecto.Query
  import Pgvector.Ecto.Query
  alias Rag.{Embedding, Generation, Retrieval}
  alias LangChain.TextSplitter.{RecursiveCharacterTextSplitter, LanguageSeparators}

  @doc_types ~w(.html .md .txt)
  @embedding_batch_size 80

  @default_splitter RecursiveCharacterTextSplitter.new!()
  @elixir_splitter RecursiveCharacterTextSplitter.new!(%{seperators: LanguageSeparators.elixir()})

  def ingest_from_hex(name, version) do
    full_name = "#{name}-#{version}"
    docs_url = "https://repo.hex.pm/docs/#{full_name}.tar.gz"
    code_url = "https://repo.hex.pm/tarballs/#{full_name}.tar"

    with {:ok, exdocs} <- hex_fetch(docs_url),
         {:ok, repo} <- hex_fetch(code_url) do
      docs =
        for {path, content} <- exdocs,
            file = to_string(path),
            Path.extname(file) in @doc_types,
            chunk <- chunk_text(file, content) do
          %{source: file, type: :docs, content: chunk}
        end

      code =
        for {file, content} <- repo["contents.tar.gz"], chunk <- chunk_text(file, content) do
          %{source: file, type: :code, content: chunk}
        end

      dependencies =
        for entry <- repo["metadata.config"]["requirements"],
            r = Map.new(entry) do
          %{name: r["name"], version_requirement: r["requirement"], optional: r["optional"]}
        end

      chunks =
        (docs ++ code)
        |> Enum.chunk_every(@embedding_batch_size)
        |> Enum.flat_map(fn batch ->
          batch
          |> Embedding.generate_embeddings_batch(embedding_provider(),
            text_key: :content,
            embedding_key: :embedding
          )
        end)

      {:ok, {chunks, dependencies}}
    end
  end

  defp hex_fetch(url) do
    [url: url]
    |> Keyword.merge(Application.get_env(:exmeralda, :hex_req_options, []))
    |> Req.new()
    |> ReqHex.attach()
    |> Req.get!()
    |> case do
      %Req.Response{status: 200, body: body} -> {:ok, body}
      %Req.Response{status: 404} -> {:error, {:repo_not_found, url}}
      response -> {:error, {:hex_fetch_error, response}}
    end
  end

  defp chunk_text(file, content) do
    file
    |> Path.extname()
    |> case do
      ".ex" -> @elixir_splitter
      _ -> @default_splitter
    end
    |> RecursiveCharacterTextSplitter.split_text(content)
  end

  def build_generation(query) do
    generation =
      Generation.new(query)
      |> Embedding.generate_embedding(embedding_provider())
      |> Retrieval.retrieve(:fulltext_results, fn generation -> query_fulltext(generation) end)
      |> Retrieval.retrieve(:semantic_results, fn generation ->
        query_with_pgvector(generation)
      end)
      |> Retrieval.reciprocal_rank_fusion(
        %{fulltext_results: 1, semantic_results: 1},
        :rrf_result
      )
      |> Retrieval.deduplicate(:rrf_result, [:source])

    context =
      Generation.get_retrieval_result(generation, :rrf_result)
      |> Enum.map_join("\n\n", & &1.document)

    context_sources =
      Generation.get_retrieval_result(generation, :rrf_result)
      |> Enum.map(& &1.source)

    prompt = prompt(query, context)

    generation
    |> Generation.put_context(context)
    |> Generation.put_context_sources(context_sources)
    |> Generation.put_prompt(prompt)
  end

  defp query_with_pgvector(%{query_embedding: query_embedding}, limit \\ 3) do
    {:ok,
     Repo.all(
       from(c in Chunk,
         order_by: l2_distance(c.embedding, ^Pgvector.new(query_embedding)),
         limit: ^limit
       )
     )}
  end

  defp query_fulltext(%{query: query}, limit \\ 3) do
    {:ok,
     Repo.all(
       from(c in Chunk,
         where: fragment("to_tsvector(?) @@ websearch_to_tsquery(?)", c.chunk, ^query),
         limit: ^limit
       )
     )}
  end

  defp prompt(query, context) do
    """
    Context information is below.
    ---------------------
    #{context}
    ---------------------
    Given the context information and no prior knowledge, answer the query.
    Query: #{query}
    Answer:
    """
  end

  defp embedding_provider do
    Application.fetch_env!(:exmeralda, :embedding)
  end
end
