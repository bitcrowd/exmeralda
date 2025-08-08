defmodule Exmeralda.Topics.IngestLibraryWorker do
  use Oban.Worker, queue: :ingest, max_attempts: 20, unique: [period: {360, :minutes}]

  import Ecto.Query
  alias Exmeralda.Repo
  alias Exmeralda.Ingestions
  alias Exmeralda.Topics
  alias Exmeralda.Topics.Ingestion

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ingestion_id" => ingestion_id}}) do
    ingestion = Repo.one!(from i in Ingestion, where: i.id == ^ingestion_id, preload: :library)

    proceed_ingestion(ingestion)
  end

  def proceed_ingestion(ingestion) do
    case do_proceed_ingestion(ingestion) do
      {:ok, ingestion} ->
        proceed_ingestion(ingestion)

      {:error, {:repo_not_found, _} = error} ->
        Topics.update_ingestion_state!(ingestion, :failed)
        {:cancel, error}

      {:error, error} ->
        {:error, error}

      :done ->
        :ok
    end
  end

  def do_proceed_ingestion(%{state: :queued} = ingestion) do
    ingestion = Topics.update_ingestion_state!(ingestion, :preprocessing)
    {:ok, ingestion}
  end

  def do_proceed_ingestion(%{state: :preprocessing} = ingestion) do
    # as we don't store documents we must handle these two steps in a transaction
    Repo.transact(fn ->
      with {:ok, documents} <- Ingestions.preprocess(ingestion),
           ingestion = Topics.update_ingestion_state!(ingestion, :chunking),
           :ok <- Ingestions.chunk_and_insert_documents(ingestion, documents) do
        ingestion = Topics.update_ingestion_state!(ingestion, :embedding)
        {:ok, ingestion}
      end
    end)
  end

  def do_proceed_ingestion(%{state: :chunking} = ingestion) do
    # we can't proceed from state chunking as we don't have the documents stored
    # go back to preprocessing
    ingestion = Topics.update_ingestion_state!(ingestion, :preprocessing)
    {:ok, ingestion}
  end

  def do_proceed_ingestion(%{state: :embedding} = ingestion) do
    {:ok, _job} = Ingestions.schedule_embeddings_worker(ingestion)
    :done
  end
end
