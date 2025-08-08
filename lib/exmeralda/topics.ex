defmodule Exmeralda.Topics do
  alias Exmeralda.Repo
  alias Exmeralda.Topics.{IngestLibraryWorker, Library, Chunk, Ingestion}
  import Ecto.Query

  def list_libraries(params) do
    Flop.validate_and_run(Library, params, replace_invalid_params: true)
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

  def list_chunks(%Library{id: id}, params) do
    from(c in Chunk, where: c.library_id == ^id)
    |> Flop.validate_and_run(params, replace_invalid_params: true, for: Chunk)
  end

  @doc """
  Schedules library ingestion
  """
  def create_library(params) do
    changeset = new_library_changeset(params)

    with {:ok, library} <- Ecto.Changeset.apply_action(changeset, :create) do
      library |> Map.take([:name, :version]) |> IngestLibraryWorker.new() |> Oban.insert()
    end
  end

  @doc """
  Schedules library ingestion for an existing library.
  """
  def reingest_library(library) do
    IngestLibraryWorker.new(%{library_id: library.id}) |> Oban.insert()
  end

  @doc """
  Deletes a libray.
  """
  def delete_library(library) do
    library |> Repo.delete()
  end

  @doc """
  Returns a changeset for ingesting a new library.
  """
  def new_library_changeset(params \\ %{}) do
    Library.changeset(%Library{}, params)
  end

  @doc """
  Returns the latest ingestion in state :ready for a library.
  """
  def current_ingestion(%Library{id: library_id}) do
    Repo.one(
      from i in Ingestion,
        where: i.library_id == ^library_id and i.state == :ready,
        order_by: [desc: :updated_at],
        limit: 1
    )
  end

  @doc """
  Updates the state of an ingestion.
  """
  def update_ingestion_state!(ingestion, state) do
    Ingestion.set_state(ingestion, state)
    |> Repo.update!()
  end

  @doc """
  Gets ingestions together with the latest associated Oban job for `scope` with Flop support for pagination, filtering, and sorting.
  """
  def list_ingestions_with_latest_job(scope \\ Ingestion, params) do
    with {:ok, flop} <- Flop.validate(params, replace_invalid_params: true, for: Ingestion) do
      job_query =
        from(Oban.Job,
          where: fragment("args->>'ingestion_id' = ?::text", parent_as(:ingestion).id),
          order_by: [desc: :attempted_at],
          limit: 1
        )

      flop = maybe_add_pagination(flop)

      {:ok,
       scope
       |> Flop.query(flop)
       |> from(as: :ingestion)
       |> preload(:library)
       |> join(:left_lateral, [i], j in subquery(job_query),
         on: fragment("args->>'ingestion_id' = ?::text", i.id)
       )
       |> select([i, j], {i, j})
       |> Flop.run(flop, for: Ingestion)}
    end
  end

  defp maybe_add_pagination(flop) do
    if flop.first || flop.last || flop.page do
      flop
    else
      %{flop | first: 10}
    end
  end

  @doc """
  Gets ingestions for `scope` with Flop support for pagination, filtering, and sorting.
  """
  def list_ingestions(scope \\ Ingestion, params) do
    scope
    |> preload(:library)
    |> Flop.validate_and_run(params, replace_invalid_params: true, for: Ingestion)
  end

  @doc """
  Gets all ingestions for a library with Flop support for pagination, filtering, and sorting.
  """
  def list_ingestions_for_library(%Library{id: library_id}, params) do
    from(i in Ingestion, where: i.library_id == ^library_id)
    |> list_ingestions(params)
  end

  @doc """
  Gets the latest ingestions.
  """
  def latest_ingestions(params) do
    from(i in Ingestion, order_by: [desc: :updated_at], preload: :library)
    |> list_ingestions(params)
  end

  @doc """
  Gets ingestions that are not ready yet.
  """
  def list_not_ready_ingestions() do
    from(i in Ingestion,
      where: i.state != :ready,
      preload: :library
    )
    |> Repo.all()
  end

  @doc """
  Gets a single ingestion.
  """
  def get_ingestion!(id) do
    Repo.get!(Ingestion, id)
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
  Lists chunks for an ingestion.
  """
  def list_chunks_for_ingestion(%Ingestion{id: id}, params) do
    from(c in Chunk, where: c.ingestion_id == ^id)
    |> Flop.validate_and_run(params, replace_invalid_params: true, for: Chunk)
  end
end
