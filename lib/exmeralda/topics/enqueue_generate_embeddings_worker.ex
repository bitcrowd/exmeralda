defmodule Exmeralda.Topics.EnqueueGenerateEmbeddingsWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20

  alias Exmeralda.Repo

  alias Exmeralda.Topics.{
    Chunk,
    Ingestion,
    GenerateEmbeddingsWorker
  }

  import Ecto.Query

  @embeddings_batch_size 20

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ingestion_id" => ingestion_id}}) do
    with {:ok, ingestion} <- fetch_ingestion(ingestion_id) do
      from(c in Chunk, where: c.ingestion_id == ^ingestion_id, select: c.id)
      |> Repo.all()
      |> Enum.chunk_every(@embeddings_batch_size)
      |> Enum.map(
        &GenerateEmbeddingsWorker.new(%{
          chunk_ids: &1,
          ingestion_id: ingestion.id
        })
      )
      |> Oban.insert_all()

      {:ok, _} = Exmeralda.Topics.poll_ingestion_state(ingestion)

      :ok
    end
  end

  defp fetch_ingestion(ingestion_id) do
    case Repo.get(Ingestion, ingestion_id) do
      %{state: :embedding} = ingestion ->
        {:ok, ingestion}

      %{state: state} ->
        {:cancel, {:ingestion_in_invalid_state, state}}

      _ ->
        {:cancel, :ingestion_not_found}
    end
  end
end
