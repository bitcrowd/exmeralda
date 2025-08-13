defmodule Exmeralda.Topics.GenerateEmbeddingsWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20

  alias Exmeralda.Repo
  alias Exmeralda.Topics
  alias Exmeralda.Topics.{Chunk, Ingestion, Rag}

  import Ecto.Query

  @embeddings_batch_size 20

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"library_id" => library_id, "ingestion_id" => ingestion_id}}) do
    Repo.transact(fn ->
      with {:ok, ingestion} <- fetch_ingestion(ingestion_id, library_id: library_id) do
        {:ok,
         from(c in Chunk, where: c.library_id == ^library_id, select: c.id)
         |> Repo.all()
         |> Enum.chunk_every(@embeddings_batch_size)
         |> Enum.map(&__MODULE__.new(%{chunk_ids: &1, ingestion_id: ingestion.id}))
         |> Oban.insert_all()}
      end
    end)
    |> case do
      {:error, :ingestion_not_found} ->
        {:cancel, :ingestion_not_found}

      {:error, {:ingestion_in_invalid_state, state}} ->
        {:cancel, {:ingestion_in_invalid_state, state}}

      {:ok, _} ->
        :ok
    end
  end

  # TODO: Maybe pass parent job ID as argument to identify child jobs
  def perform(%Oban.Job{args: %{"chunk_ids" => ids, "ingestion_id" => ingestion_id}}) do
    Repo.transact(fn ->
      with {:ok, ingestion} <- fetch_ingestion(ingestion_id) do
        from(c in Chunk, where: c.id in ^ids)
        |> Repo.all()
        |> Rag.generate_embeddings()
        |> Enum.map(&Chunk.set_embedding(Map.put(&1, :embedding, nil), &1.embedding))
        |> Enum.each(&Repo.update!/1)

        if all_chunks_embedded?(ingestion.id) do
          Topics.update_ingestion_state!(ingestion, :ready)
        end

        {:ok, ingestion}
      end
    end)
    |> case do
      {:error, :ingestion_not_found} ->
        {:cancel, :ingestion_not_found}

      {:error, {:ingestion_in_invalid_state, state}} ->
        {:cancel, {:ingestion_in_invalid_state, state}}

      {:ok, _} ->
        :ok
    end
  end

  defp fetch_ingestion(ingestion_id, opts \\ []) do
    case Repo.get(Ingestion, ingestion_id) do
      %{state: :embedding} = ingestion ->
        check_library_id(ingestion, Keyword.get(opts, :library_id))

      %{state: state} ->
        {:error, {:ingestion_in_invalid_state, state}}

      _ ->
        {:error, :ingestion_not_found}
    end
  end

  defp check_library_id(%{library_id: library_id} = ingestion, library_id),
    do: check_library_id(ingestion, nil)

  defp check_library_id(ingestion, nil), do: {:ok, Repo.preload(ingestion, [:library])}
  defp check_library_id(_, _), do: {:error, :ingestion_not_found}

  defp all_chunks_embedded?(ingestion_id) do
    query = from(c in Chunk, where: c.ingestion_id == ^ingestion_id and is_nil(c.embedding))

    not Repo.exists?(query)
  end
end
