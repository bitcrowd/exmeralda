# Simple RAG evaluation

(also as a Livebook)

Start an iex session attached to the app:

```sh
iex -S mix
```

## Helper module

Paste this once at the top of your iex session. Every subsequent snippet uses it
instead of re-importing/aliasing the same things over and over. It's intentionally
**not** part of the codebase — it only lives in your session.

```Elixir
defmodule Work do
  import Ecto.Query
  import Pgvector.Ecto.Query
  alias Exmeralda.{Repo, Topics.Chunk, Topics.Ingestion}

  def provider do
    cfg = Application.fetch_env!(:exmeralda, :embedding_config)
    Exmeralda.Rag.Ollama.new(Map.put(cfg.config, :embeddings_model, cfg.model))
  end

  def embed(text) when is_binary(text) do
    [vec] = embed_many([text])
    vec
  end

  def embed_many(texts) when is_list(texts) do
    {:ok, vecs} = Exmeralda.Rag.Ollama.generate_embeddings(provider(), texts, [])
    vecs
  end

  def latest_ingestion_id(library_name) do
    Repo.one!(
      from i in Ingestion,
        join: l in assoc(i, :library),
        where: l.name == ^library_name and i.state == :ready,
        order_by: [desc: i.inserted_at],
        limit: 1,
        select: i.id
    )
  end

  def semantic_search(ingestion_id, query_or_vector, limit \\ 0) do
    vec = if is_binary(query_or_vector), do: embed(query_or_vector), else: query_or_vector
    qvec = Pgvector.new(vec)

    base =
      from c in Chunk,
        where: c.ingestion_id == ^ingestion_id and not is_nil(c.embedding),
        order_by: l2_distance(c.embedding, ^qvec),
        select: %{
          chunk_id: c.id,
          source: c.source,
          distance: l2_distance(c.embedding, ^qvec)
        }

    query = if limit > 0, do: from(q in base, limit: ^limit), else: base
    Repo.all(query)
  end

  def semantic_search_within(ingestion_id, query_or_vector, max_distance) do
    vec = if is_binary(query_or_vector), do: embed(query_or_vector), else: query_or_vector
    qvec = Pgvector.new(vec)

    Repo.all(
      from c in Chunk,
        where:
          c.ingestion_id == ^ingestion_id and not is_nil(c.embedding) and
            l2_distance(c.embedding, ^qvec) <= ^max_distance,
        order_by: l2_distance(c.embedding, ^qvec),
        limit: 5,
        select: %{
          chunk_id: c.id,
          source: c.source,
          distance: l2_distance(c.embedding, ^qvec)
        }
    )
  end

  def inject_chunks(ingestion_id, source_prefix, texts) do
    vectors = embed_many(texts)

    rows =
      texts
      |> Enum.zip(vectors)
      |> Enum.with_index(1)
      |> Enum.map(fn {{content, vec}, i} ->
        %{
          ingestion_id: ingestion_id,
          type: :docs,
          source: "#{source_prefix}/#{i}.txt",
          content: content,
          embedding: Pgvector.new(vec)
        }
      end)

    {inserted, _} = Repo.insert_all(Chunk, rows)
    inserted
  end

  def count_by_source(ingestion_id, like_pattern) do
    Repo.aggregate(
      from(c in Chunk,
        where: c.ingestion_id == ^ingestion_id and like(c.source, ^like_pattern)),
      :count
    )
  end

  def delete_by_source(ingestion_id, like_pattern) do
    Repo.delete_all(
      from c in Chunk,
        where: c.ingestion_id == ^ingestion_id and like(c.source, ^like_pattern)
    )
  end
end
```

## Picking an ingestion

```Elixir
ingestion_id = Work.latest_ingestion_id("jason")
```

## Encoding a query into an embedding vector

```Elixir
embedding = Work.embed("How do I decode a JSON string into a map with Jason?")
length(embedding)        # 768 for jina-embeddings-v2-base-code
Enum.take(embedding, 5)
```

## Semantic search

Default (no limit — returns every chunk in the ingestion, closest first):

```Elixir
results = Work.semantic_search(ingestion_id, "How do I decode a JSON string into a map with Jason?")
```

Pass a limit as the third argument when you want just the top N:

```Elixir
top_ten = Work.semantic_search(ingestion_id, "How do I decode a JSON string into a map with Jason?", 10)
```

Pre-computed vectors work too — same positional rules:

```Elixir
Work.semantic_search(ingestion_id, embedding)        # all results
Work.semantic_search(ingestion_id, embedding, 10)    # top 10
```

### Semantic search with a distance threshold

`semantic_search_within/3` drops rows whose L2 distance exceeds `max_distance`
and returns at most 5 results (closest first). Useful when you want "only
chunks that are actually relevant" rather than "top N no matter what":

```Elixir
Work.semantic_search_within(ingestion_id, "How do I decode JSON?", 0.8)
```

Tuning tip: look at the distance column from an unlimited `semantic_search/3`
run first, pick a threshold that sits somewhere in the gap between "clearly
relevant" and "noise", and use that number.

## Asking about Paris:

top_ten = Work.semantic_search(ingestion_id, "Tell me about Paris", 10)

## Injecting off-topic chunks (distraction test)

```Elixir
paris_chunks = [
  "Paris is the capital and most populous city of France, situated on the Seine River in the north-central part of the country.",
  "The Eiffel Tower, completed in 1889 for the World's Fair, stands 330 meters tall and remains the most visited paid monument in Paris.",
  "The Louvre, once a royal palace, is Paris's largest art museum and home to Leonardo da Vinci's Mona Lisa and the ancient Venus de Milo.",
  "Notre-Dame de Paris, a masterpiece of French Gothic architecture, was constructed between 1163 and 1345 on the Île de la Cité and severely damaged by fire in 2019.",
  "Paris is often called the City of Light (La Ville Lumière), a nickname earned both from its leading role during the Age of Enlightenment and from being one of the first European cities to adopt gas street lighting."
]

Work.inject_chunks(ingestion_id, "paris/info", paris_chunks)
```

### Search for them

```Elixir
Work.semantic_search(ingestion_id, "Tell me things about Paris")
```

The `paris/info_*.txt` sources should dominate the top of the list — the injected
content is near-identical to the query in vector space, so it beats every jason
chunk.

### Clean up afterwards

```Elixir
Work.count_by_source(ingestion_id, "paris/%")
Work.delete_by_source(ingestion_id, "paris/%")
```
