defmodule Exmeralda.Topics.Rag do
  @moduledoc false
  alias Exmeralda.Repo
  import Ecto.Query
  import Pgvector.Ecto.Query
  alias Rag.{Embedding, Generation, Retrieval}
  alias LangChain.TextSplitter.{RecursiveCharacterTextSplitter, LanguageSeparators}

  @doc_types ~w(.html .md .txt)
  @embedding_batch_size 80
  @retrieval_weights %{fulltext_results: 1, semantic_results: 1}
  @pgvector_limit 3
  @fulltext_limit 3
  @excluded_docs ~w(404.html)

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
            Path.extname(file) in @doc_types and file not in @excluded_docs,
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

  def build_generation(scope, query, opts \\ []) do
    generation =
      Generation.new(query, opts)
      |> Embedding.generate_embedding(embedding_provider())
      |> Retrieval.retrieve(:fulltext_results, &query_fulltext(&1, scope))
      |> Retrieval.retrieve(:semantic_results, &query_with_pgvector(&1, scope))
      |> Retrieval.reciprocal_rank_fusion(@retrieval_weights, :rrf_result)
      |> Retrieval.deduplicate(:rrf_result, [:source])

    result = Generation.get_retrieval_result(generation, :rrf_result)
    context = Enum.map_join(result, "\n\n", & &1.content)
    context_sources = Enum.map(result, & &1.source)

    prompt = prompt(query, context)

    {result,
     generation
     |> Generation.put_context(context)
     |> Generation.put_context_sources(context_sources)
     |> Generation.put_prompt(prompt)}
  end

  defp query_with_pgvector(%{query_embedding: query_embedding}, scope) do
    {:ok,
     Repo.all(
       scope
       |> order_by([c], l2_distance(c.embedding, ^Pgvector.new(query_embedding)))
       |> limit(@pgvector_limit)
     )}
  end

  defp query_fulltext(%{query: query}, scope) do
    {:ok,
     Repo.all(
       scope
       |> order_by(fragment("search @@ websearch_to_tsquery(?)", ^query))
       |> limit(@fulltext_limit)
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
