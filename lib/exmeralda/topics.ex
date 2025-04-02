defmodule Exmeralda.Topics do
  alias Exmeralda.Repo
  alias Exmeralda.Topics.{IngestLibraryWorker, Library, Chunk}
  import Ecto.Query

  def last_libraries() do
    from(l in Library,
      as: :library,
      order_by: [desc: :inserted_at],
      limit: 10
    )
    |> with_chunks_ready()
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
    |> with_chunks_ready()
    |> Repo.all()
  end

  defp with_chunks_ready(query) do
    where(
      query,
      [l],
      not exists(
        from c in Chunk,
          where: c.library_id == parent_as(:library).id and is_nil(c.embedding),
          select: 1,
          limit: 1
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
  Schedules library ingestion
  """
  def create_library(params) do
    changeset = new_library_changeset(params)

    with {:ok, library} <- Ecto.Changeset.apply_action(changeset, :create) do
      library |> Map.take([:name, :version]) |> IngestLibraryWorker.new() |> Oban.insert()
    end
  end

  @doc """
  Returns a changeset for ingesting a new library.
  """
  def new_library_changeset(params \\ %{}) do
    Library.changeset(%Library{}, params)
  end
end
