defmodule Exmeralda.Topics.IngestLibraryWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20, unique: [period: {360, :minutes}]

  import Ecto.Query
  alias Exmeralda.Repo
  alias Exmeralda.Ingestions
  alias Exmeralda.Topics.{Ingestion}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ingestion_id" => ingestion_id}}) do
    ingestion = Repo.one!(from i in Ingestion, where: i.id == ^ingestion_id, preload: :library)

    proceed_ingestion(ingestion)
  end

  def proceed_ingestion(ingestion) do
    case do_proceed_ingestion(ingestion) do
      {:ok, ingestion} -> proceed_ingestion(ingestion)
      {:error, {:repo_not_found, _} = error} -> {:cancel, error}
      {:error, error} -> {:error, error}
      :done -> :ok
    end
  end

  def do_proceed_ingestion(%{state: :queued} = ingestion) do
    Ingestions.set_preprocessing(ingestion)
  end

  def do_proceed_ingestion(%{state: :preprocessing} = ingestion) do
    Ingestions.set_chunking(ingestion)
  end

  def do_proceed_ingestion(%{
        ingestion: %{state: :chunking} = ingestion,
        args: %{docs: docs, code: code}
      }) do
    Ingestions.set_embedding(ingestion, %{docs: docs, code: code})
  end

  def do_proceed_ingestion(%{state: :embedding} = ingestion) do
    Ingestions.schedule_embeddings_worker(ingestion)
    :done
  end
end
