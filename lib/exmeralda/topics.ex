defmodule Exmeralda.Topics do
  import Ecto.Query
  alias Exmeralda.Repo

  alias Exmeralda.Topics.{
    IngestLibraryWorker,
    DeliverIngestionInProgressEmailWorker,
    Library,
    Chunk,
    Ingestion
  }

  alias Exmeralda.Chats

  alias Exmeralda.Accounts.User

  def list_libraries(params) do
    Flop.validate_and_run(Library, params, replace_invalid_params: true, for: Library)
  end

  def last_libraries() do
    from(l in Library,
      as: :library,
      order_by: [desc: :inserted_at],
      limit: 10
    )
    |> with_ingestion_ready()
    |> Repo.all()
  end

  def search_libraries(term) do
    term = normalize_search_term(term)

    from(
      l in Library,
      as: :library,
      where:
        fragment(
          "search @@ to_tsquery(?)",
          ^term
        ),
      order_by: [
        desc:
          fragment(
            "ts_rank_cd(search, to_tsquery(?))",
            ^term
          ),
        asc: :name,
        desc: :version
      ]
    )
    |> with_ingestion_ready()
    |> Repo.all()
  end

  defp with_ingestion_ready(query) do
    where(
      query,
      [l],
      exists(
        from i in Ingestion, where: i.library_id == parent_as(:library).id and i.state == :ready
      )
    )
  end

  # Splits a search term by spaces and appends a prefix match wildcard (:*)
  # to each word for partial prefix matching in full-text search.
  #
  # Example:
  #
  #   normalize_query("abc xyz")
  #   > "'abc:*' & 'xyz:*'"
  #
  defp normalize_search_term(term) do
    term
    |> String.replace("'", "''")
    |> String.replace("\\", "\\\\")
    |> String.split(~r(\s), trim: true)
    |> Enum.map_join(" & ", &"'#{&1}':*")
  end

  @doc """
  Gets a single library.
  """
  def get_library!(id) do
    Repo.get!(Library, id)
  end

  @doc """
  Creates a library and ingestion, schedules the ingestion.
  """
  @spec create_library(User.t(), map()) ::
          {:ok, %{library: Library.t(), ingestion: Ingestion.t()}} | {:error, Ecto.Changeset.t()}
  def create_library(user, params) do
    Repo.transact(fn ->
      with {:ok, library} <- do_create_library(params),
           {:ok, ingestion} <- create_ingestion(library),
           :ok <- notify_user(user, library) do
        {:ok, %{library: library, ingestion: ingestion}}
      end
    end)
  end

  defp do_create_library(params) do
    params
    |> new_library_changeset()
    |> Repo.insert()
  end

  defp create_ingestion(library) do
    if !Repo.in_transaction?(), do: raise("not in a transaction")

    with {:ok, ingestion} <- do_create_ingestion(library),
         {:ok, oban_job} <- schedule_ingestion_worker(ingestion),
         {:ok, updated_ingestion} <- set_ingestion_job_id(ingestion, oban_job),
         :ok <-
           broadcast(
             "ingestions",
             {:ingestion_created, Repo.preload(updated_ingestion, [:library, :job])}
           ) do
      {:ok, updated_ingestion}
    end
  end

  defp do_create_ingestion(library) do
    Ingestion.changeset(%{library_id: library.id, state: :queued})
    |> Repo.insert()
  end

  defp schedule_ingestion_worker(ingestion) do
    IngestLibraryWorker.new(%{ingestion_id: ingestion.id})
    |> Oban.insert()
  end

  def set_ingestion_job_id(ingestion, oban_job) do
    ingestion
    |> Ingestion.set_ingestion_job_id(oban_job.id)
    |> Repo.update()
  end

  defp notify_user(user, library) do
    DeliverIngestionInProgressEmailWorker.new(%{user_id: user.id, library_id: library.id})
    |> Oban.insert()

    :ok
  end

  defp broadcast(topic, event) do
    Phoenix.PubSub.broadcast(Exmeralda.PubSub, topic, event)
  end

  @doc """
  Schedules library ingestion for an existing library.
  """
  @spec reingest_library(Library.id()) :: {:ok, Ingestion.t()} | {:error, {:not_found, Library}}
  def reingest_library(library_id) do
    Repo.transact(fn ->
      with {:ok, library} <- Repo.fetch(Library, library_id) do
        create_ingestion(library)
      end
    end)
  end

  @doc """
  Deletes a library.
  """
  @spec delete_library(Library.id()) ::
          {:ok, :ok} | {:ok, Library.t()} | {:error, :library_has_chats}
  def delete_library(library_id) do
    Repo.transact(fn ->
      with {:ok, library} <- Repo.fetch(Library, library_id),
           :ok <- Repo.advisory_xact_lock("library:#{library_id}") do
        do_delete_library(library)
      else
        {:error, {:not_found, Library}} -> {:ok, :ok}
      end
    end)
  end

  defp do_delete_library(library) do
    if Enum.empty?(Chats.list_sessions_for_library(library.id)) do
      Repo.delete(library)
    else
      {:error, :library_has_chats}
    end
  end

  @doc """
  Returns a changeset for ingesting a new library.
  """
  def new_library_changeset(params \\ %{}) do
    Library.changeset(%Library{}, params)
  end

  @doc """
  Returns the active ingestion for a library.
  """
  @spec active_ingestion(Library.id()) :: {:ok, Ingestion.t()} | {:error, {:not_found, Ingestion}}
  def active_ingestion(library_id) do
    Repo.fetch_by(Ingestion, library_id: library_id, active: true)
  end

  @doc """
  Updates the state of an ingestion and broadcasts the update.
  """
  def update_ingestion_state!(ingestion, state) do
    ingestion =
      ingestion
      |> Ingestion.set_state(state)
      |> Repo.update!()

    Phoenix.PubSub.broadcast(
      Exmeralda.PubSub,
      "ingestions",
      {:ingestion_state_updated, Repo.preload(ingestion, [:library, :job])}
    )

    ingestion
  end

  @doc """
  Gets all ingestions for a library with Flop support for pagination, filtering, and sorting.
  """
  def list_ingestions(%Library{id: library_id}, params) do
    from(i in Ingestion, where: i.library_id == ^library_id)
    |> Flop.validate_and_run(params, replace_invalid_params: true, for: Ingestion)
  end

  @doc """
  Gets the latest ingestions in given states.
  """
  def last_ingestions(states) do
    from(i in Ingestion,
      where: i.state in ^states,
      order_by: [desc: :inserted_at],
      preload: [:library, :job],
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Gets a single ingestion.
  """
  def get_ingestion!(id, opts \\ []) do
    preloads = Keyword.get(opts, :preloads)
    Repo.get!(Ingestion, id) |> Repo.preload(preloads)
  end

  @doc """
  Gets stats for chunks belonging to an ingestion.
  """
  def get_ingestion_stats(%Ingestion{id: id}) do
    chunks = from c in Chunk, where: c.ingestion_id == ^id

    %{
      chunks_total: chunks |> Repo.aggregate(:count),
      chunks_embedding: chunks |> where([c], not is_nil(c.embedding)) |> Repo.aggregate(:count),
      chunks_type:
        chunks |> group_by([c], c.type) |> select([c], {c.type, count(c.id)}) |> Repo.all()
    }
  end

  @doc """
  Gets the number of embedding chunk jobs that are completed.
  """
  def get_embedding_chunks_jobs(%{state: :embedding} = ingestion) do
    query =
      from(oj in Oban.Job,
        where:
          oj.worker == "Exmeralda.Topics.GenerateEmbeddingsWorker" and
            fragment("args->>'ingestion_id' = ?::text", ^ingestion.id) and
            fragment("args->>'parent_job_id' = ?::text", ^to_string(ingestion.job_id))
      )

    %{
      total: Repo.aggregate(query, :count),
      completed: Repo.aggregate(where(query, [oj], oj.state == "completed"), :count)
    }
  end

  def get_embedding_chunks_jobs(_), do: nil

  @doc """
  Lists chunks for an ingestion.
  """
  def list_chunks_for_ingestion(%Ingestion{id: id}, params) do
    from(c in Chunk, where: c.ingestion_id == ^id)
    |> Flop.validate_and_run(params, replace_invalid_params: true, for: Chunk)
  end

  @spec delete_ingestion(Ingestion.id()) ::
          {:ok, :ok}
          | {:ok, Ingestion.t()}
          | {:error, :ingestion_has_chats}
          | {:error, :ingestion_invalid_state}
  def delete_ingestion(ingestion_id) do
    Repo.transact(fn ->
      with {:ok, ingestion} <- Repo.fetch(Ingestion, ingestion_id),
           :ok <- Repo.advisory_xact_lock("library:#{ingestion.library_id}") do
        do_delete_ingestion(ingestion)
      else
        {:error, {:not_found, Ingestion}} -> {:ok, :ok}
      end
    end)
  end

  defp do_delete_ingestion(ingestion) do
    cond do
      ingestion.state not in [:ready, :failed] -> {:error, :ingestion_invalid_state}
      Enum.empty?(Chats.list_sessions_for_ingestion(ingestion.id)) -> Repo.delete(ingestion)
      true -> {:error, :ingestion_has_chats}
    end
  end

  @spec mark_ingestion_as_active(Ingestion.id()) ::
          {:ok, Ingestion.t()}
          | {:error, {:not_found, Ingestion}}
          | {:error, :ingestion_invalid_state}
          | {:error, :ingestion_already_active}
  def mark_ingestion_as_active(ingestion_id) do
    Repo.transact(fn ->
      with {:ok, ingestion} <- fetch_ingestion(ingestion_id),
           :ok <- check_ingestion_inactive(ingestion),
           :ok <- Repo.advisory_xact_lock("library:#{ingestion.library_id}") do
        do_mark_ingestion_as_active(ingestion)
      end
    end)
  end

  defp fetch_ingestion(ingestion_id) do
    case Repo.fetch(Ingestion, ingestion_id) do
      {:error, {:not_found, Ingestion}} -> {:error, {:not_found, Ingestion}}
      {:ok, %{state: state}} when state != :ready -> {:error, :ingestion_invalid_state}
      {:ok, ingestion} -> {:ok, ingestion}
    end
  end

  defp check_ingestion_inactive(%{active: true}), do: {:error, :ingestion_already_active}
  defp check_ingestion_inactive(_), do: :ok

  defp do_mark_ingestion_as_active(ingestion) do
    case active_ingestion(ingestion.library_id) do
      {:ok, active_ingestion} ->
        mark_ingestion_as_inactive!(active_ingestion)

      {:error, {:not_found, _}} ->
        :ok
    end

    {:ok, mark_ingestion_as_active!(ingestion)}
  end

  defp mark_ingestion_as_active!(ingestion) do
    ingestion
    |> Ingestion.set_ingestion_active_changeset()
    |> Repo.update!()
  end

  @spec mark_ingestion_as_inactive(Ingestion.id()) ::
          {:ok, Ingestion.t()}
          | {:error, {:not_found, Ingestion}}
          | {:error, :ingestion_invalid_state}
          | {:error, :ingestion_already_inactive}
  def mark_ingestion_as_inactive(ingestion_id) do
    Repo.transact(fn ->
      with {:ok, ingestion} <- fetch_ingestion(ingestion_id),
           :ok <- check_ingestion_active(ingestion),
           :ok <- Repo.advisory_xact_lock("library:#{ingestion.library_id}") do
        {:ok, mark_ingestion_as_inactive!(ingestion)}
      end
    end)
  end

  defp check_ingestion_active(%{active: false}), do: {:error, :ingestion_already_inactive}
  defp check_ingestion_active(_), do: :ok

  defp mark_ingestion_as_inactive!(ingestion) do
    ingestion
    |> Ingestion.set_ingestion_inactive_changeset()
    |> Repo.update!()
  end
end
