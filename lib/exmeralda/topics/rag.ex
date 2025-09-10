defmodule Exmeralda.Topics.Rag do
  @moduledoc false
  alias Exmeralda.Repo
  import Ecto.Query
  import Pgvector.Ecto.Query
  alias Exmeralda.Topics.{Hex, LineCheck}
  alias Exmeralda.Chats.GenerationEnvironment
  alias Rag.{Embedding, Generation, Retrieval}
  alias LangChain.TextSplitter.{RecursiveCharacterTextSplitter, LanguageSeparators}
  require Logger

  @doc_types ~w(.html .md .txt)
  @chunk_size 2000
  @retrieval_weights %{fulltext_results: 1, semantic_results: 1}
  @pgvector_limit 3
  @fulltext_limit 3
  @fulltext_min_rank 0.003
  @excluded_docs ~w(404.html)
  @excluded_code_types ~w(.map)

  @default_splitter RecursiveCharacterTextSplitter.new!(%{chunk_size: @chunk_size})
  @elixir_splitter RecursiveCharacterTextSplitter.new!(%{
                     seperators: LanguageSeparators.elixir(),
                     chunk_size: @chunk_size
                   })
  @js_splitter RecursiveCharacterTextSplitter.new!(%{
                 seperators: LanguageSeparators.js(),
                 chunk_size: @chunk_size
               })
  @markdown_splitter RecursiveCharacterTextSplitter.new!(%{
                       seperators: LanguageSeparators.markdown(),
                       chunk_size: @chunk_size
                     })

  def ingest_from_hex(name, version) do
    with {:ok, exdocs} <- Hex.docs(name, version),
         {:ok, repo} <- Hex.tarball(name, version) do
      docs =
        for {path, content} <- exdocs,
            file = to_string(path),
            Path.extname(file) in @doc_types and file not in @excluded_docs,
            chunk <- chunk_text(file, content) do
          %{source: file, type: :docs, content: chunk}
        end

      code =
        for {file, content} <- repo["contents.tar.gz"],
            String.valid?(content),
            LineCheck.valid?(content),
            Logger.debug("Chunking #{file} from #{name}-#{version}"),
            Path.extname(file) not in @excluded_code_types,
            chunk <- chunk_text(file, content) do
          %{source: file, type: :code, content: Enum.join(["# #{file}\n\n", chunk])}
        end

      dependencies =
        for entry <- repo["metadata.config"]["requirements"] do
          r =
            case entry do
              {name, meta} -> Map.new(meta) |> Map.put("name", name)
              value -> Map.new(value)
            end

          %{name: r["name"], version_requirement: r["requirement"], optional: r["optional"]}
        end

      chunks = docs ++ code

      {:ok, {chunks, dependencies}}
    end
  end

  def generate_embeddings(chunks) do
    Embedding.generate_embeddings_batch(chunks, embedding_provider(),
      text_key: :content,
      embedding_key: :embedding
    )
  end

  defp chunk_text(file, content) do
    file
    |> Path.extname()
    |> case do
      ".ex" -> @elixir_splitter
      ".exs" -> @elixir_splitter
      ".js" -> @js_splitter
      ".md" -> @markdown_splitter
      _ -> @default_splitter
    end
    |> RecursiveCharacterTextSplitter.split_text(content)
  end

  def build_generation(scope, message, opts \\ []) do
    %{generation_environment_id: generation_environment_id, content: query} = message

    generation =
      Generation.new(query, opts)
      |> Embedding.generate_embedding(embedding_provider())
      |> Retrieval.retrieve(:fulltext_results, &query_fulltext(&1, scope))
      |> Retrieval.retrieve(:semantic_results, &query_with_pgvector(&1, scope))
      |> Retrieval.reciprocal_rank_fusion(@retrieval_weights, :rrf_result)
      |> Retrieval.deduplicate(:rrf_result, [:id])

    result = Generation.get_retrieval_result(generation, :rrf_result)
    context = Enum.map_join(result, "\n\n", & &1.content)
    context_sources = Enum.map(result, & &1.source)

    prompt = prompt(generation_environment_id, query, context)

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
       |> where([c], not is_nil(c.embedding))
       |> order_by([c], l2_distance(c.embedding, ^Pgvector.new(query_embedding)))
       |> limit(@pgvector_limit)
     )}
  end

  defp query_fulltext(%{query: query}, scope) do
    ranked_subquery =
      from(c in scope,
        select: %{
          id: c.id,
          source: c.source,
          content: c.content,
          rank: fragment("ts_rank(search, plainto_tsquery('english', ?))", ^query)
        }
      )

    {:ok,
     Repo.all(
       from(r in subquery(ranked_subquery),
         select: %{
           id: r.id,
           source: r.source,
           rank: r.rank,
           content: r.content
         },
         where: r.rank > ^@fulltext_min_rank,
         order_by: [desc: r.rank],
         limit: ^@fulltext_limit
       )
     )}
  end

  defp prompt(generation_environment_id, query, context) do
    %{generation_prompt: generation_prompt} =
      Repo.get!(GenerationEnvironment, generation_environment_id)
      |> Repo.preload([:generation_prompt])

    generation_prompt.prompt
    |> String.replace("%{query}", query, global: true)
    |> String.replace("%{context}", context, global: true)
  end

  defp embedding_provider do
    case Application.fetch_env!(:exmeralda, :embedding) do
      embedding when is_struct(embedding) -> embedding
      mod when is_atom(mod) -> mod.new(%{})
    end
  end
end
