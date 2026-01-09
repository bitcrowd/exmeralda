defmodule Exmeralda.Topics.Rag.Evaluation do
  @moduledoc """
  ⚠️ The generation environment needs to exist. Create it yourself or run the seeds first. ⚠️
  (with `mix seed`).

  ### Usage

  1. Run the server with an iex console: `iex -S mix phx.server`
  2. Call with
  ```
    Exmeralda.Topics.Rag.Evaluation.batch_question_generation(
      <<< INGESTION ID >>>,
      <<< GENERATION ENVIRONMENT ID >>>,
      download: true
    )
  ```
  That will save a json file in the default @download_dir.
  3. To run the evaluation:

  ```
    Exmeralda.Topics.Rag.Evaluation.batch_evaluation(
      <<< PATH TO QUESTION JSON FILE >>>
    )
  ```
  This will print the result to the console.

  #### Options
  - `download: true` -> That will save a csv file with the results of the evaluation in the default @download_dir.
  - `download_dir` -> To specify the directory the csv is downloaded into.
  - `aggregate: true` -> To return aggregated results. Per default aggregated results are returned for all the
    steps of the retrieval strategy.
  - `results` -> To get evaluations for specific steps of the retrieval strategy
    (`rrf_result` -> final result, `semantic_results`, `fulltext_results`).
    Default: `rrf_result`, for aggregate: all result types.

  ### Individual usage

  - You can use `question_generation/2,3` to generate a *single* question for a given chunk
  - You can use `evaluate/1` to run the evaluation for a *single* question
  """
  require Logger
  import Ecto.Query
  alias Exmeralda.Chats.GenerationEnvironment
  alias Exmeralda.Repo
  alias Exmeralda.Chats.LLM
  alias Exmeralda.Chats
  alias Exmeralda.Topics.{Chunk, Ingestion}

  @type question :: %{
          chunk_id: Chunk.id(),
          generation_environment_id: GenerationEnvironment.id(),
          question: String.t()
        }
  @type filepath :: String.t()
  @type batch_questions_opts :: [
          limit: non_neg_integer(),
          download: boolean(),
          download_dir: filepath()
        ]
  @type batch_evaluation_opts :: [
          download: boolean(),
          download_dir: filepath(),
          aggregate: boolean(),
          results: [result_type()]
        ]
  @type question_opts :: [content: String.t()]
  @type evaluation :: %{
          question: question(),
          ingestion_id: Ingestion.id(),
          first_hit_correct?: boolean(),
          first_hit_id: Chunk.id(),
          total_chunks_found: pos_integer(),
          chunk_found?: boolean(),
          chunk_rank: pos_integer() | nil
        }
  @type result_type :: :rrf_result | :fulltext_results | :semantic_results

  @download_dir "./rag_evaluations"

  @doc """
  Generates a question for chunks of a given ingestion, using the provided
  generation environment.

  # Opts
  - limit: By default, only 2 chunks are randomly picked from the ingestion. This can be changed
    by passing the option.
  - download: By default, only printing the questions in the console. To download the questions
  as JSON, pass download: true.
  - download_path: Where to download the JSON, defaults to "./rag_evaluations"
  """
  @spec batch_question_generation(Ingestion.id(), GenerationEnvironment.id()) :: [question()]
  @spec batch_question_generation(
          Ingestion.id(),
          GenerationEnvironment.id(),
          batch_questions_opts()
        ) ::
          [question()] | {:ok, filepath()}
  def batch_question_generation(ingestion_id, generation_environment_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 2)
    download? = Keyword.get(opts, :download, false)
    download_dir = Keyword.get(opts, :download_dir, @download_dir)
    ingestion = Repo.get!(Ingestion, ingestion_id)

    if ingestion.state != :ready, do: raise("ingestion not ready")

    results =
      from(c in Chunk,
        where:
          c.ingestion_id == ^ingestion_id and not is_nil(c.embedding) and
            fragment("? LIKE 'lib/%'", c.source),
        # TODO: Well this is random, ideally we don't want to reuse always the same chunks
        # But since the LLM request is so long, it could make sense to involve Oban in the mix
        # and save the questions in a DB table.
        order_by: fragment("RANDOM()"),
        limit: ^limit
      )
      |> Repo.all()
      |> async_question_generation(generation_environment_id, limit)

    if download? && Mix.env() != :prod do
      download(download_dir, questions_filename(ingestion), Jason.encode!(results))
    else
      results
    end
  end

  defp async_question_generation(chunks, generation_environment_id, limit) do
    chunks
    |> Enum.with_index()
    |> Enum.map(fn {chunk, index} ->
      Logger.info("⌛️ Generating question #{index + 1}/#{limit}, please wait...")

      Task.async(__MODULE__, :do_question_generation, [chunk, generation_environment_id, []])
    end)
    |> Task.await_many(:infinity)
    |> Enum.map(fn result ->
      case result do
        {:ok, question} -> question
        {:error, error} -> raise error
      end
    end)
  end

  defp questions_filename(ingestion) do
    "#{ingestion.id}_questions_#{DateTime.to_iso8601(DateTime.utc_now(), :basic)}.json"
  end

  defp download(download_dir, filename, data) do
    if !File.exists?(download_dir), do: File.mkdir!(download_dir)
    path = Path.join(download_dir, filename)
    File.write!(path, data)
    Logger.info("✅ Download finished! Check the file: #{path}")
    {:ok, path}
  end

  @rag_evaluation_generation_prompt """
  You are given a piece of technical documentation.

  Perform three tasks:

  1. **Extract the key assertions**
  • Read the text carefully.
  • List every important assertion the docs make (what the feature *is*, how it *works*, guarantees, limits, options, notes, etc.).
  • Phrase each important assertion as a single, self-contained sentence.
  • Outline the assertions that only this document makes and that will most likely be unique to this document in a list.

  2. **Invent realistic Stack-Overflow-style questions**
  • Think of developers encountering issues that this doc resolves.
  • For **each** imagined user, write a Question:
  –It should start with a first-person sentence that includes a tiny code snippet or concrete detail (e.g. `Req.get!("…", into: :self)`). the direct question they would post (“Why does …?”, “How can I …?”).

  3. Select the most significant question and output it

  • The question must be answerable solely with the assertions from task 1.

  The documentation is:
  ======= begin documentation =======
  %{content}
  ======= end documentation =======


  Do not output the assertions
  Do output only the question
  Output only the one selected Question
  """

  @doc """
  Generates a question for a given chunk ID and generation environment.
  By default the question uses the chunk's content. If a `content` option is passed,
  we use this content string instead of the chunk's content.
  """
  @spec question_generation(Chunk.id(), GenerationEnvironment.id()) ::
          {:ok, question} | {:error, :chunk_not_embedded} | {:error, any()}
  @spec question_generation(Chunk.id(), GenerationEnvironment.id(), question_opts()) ::
          {:ok, question} | {:error, :chunk_not_embedded} | {:error, any()}
  def question_generation(
        chunk_id,
        generation_environment_id,
        opts \\ []
      ) do
    Chunk
    |> Repo.get!(chunk_id)
    |> case do
      %{embedding: nil} -> {:error, :chunk_not_embedded}
      chunk -> do_question_generation(chunk, generation_environment_id, opts)
    end
  end

  def do_question_generation(
        chunk,
        generation_environment_id,
        opts
      ) do
    content = Keyword.get(opts, :content, chunk.content)

    case LLM.stream_responses([build_message(content)], generation_environment_id, %{}) do
      {:ok, %{last_message: last_message}} ->
        {:ok,
         %{
           chunk_id: chunk.id,
           question: last_message.content,
           generation_environment_id: generation_environment_id
         }}

      {:error, _chain, error} ->
        {:error, error}
    end
  end

  defp build_message(content) do
    %{
      role: :user,
      content:
        String.replace(@rag_evaluation_generation_prompt, "%{content}", content, global: true)
    }
  end

  @doc """
  Evaluates the retrieval for a given chunk, question and generation environment.
  Ideally, that should be used after generating questions with batch_generating_question.
  """
  @spec evaluate(question()) :: %{result_type() => evaluation()}
  @spec evaluate(question(), opts :: keyword()) :: %{result_type() => evaluation()}
  def evaluate(
        %{
          chunk_id: chunk_id,
          question: question,
          generation_environment_id: generation_environment_id
        } = question_map,
        opts \\ []
      ) do
    results = Keyword.get(opts, :results, [:rrf_result])
    chunk = Repo.get!(Chunk, chunk_id)

    {_chunks, generation} =
      %{
        generation_environment_id: generation_environment_id,
        content: question
      }
      |> Chats.build_generation(chunk.ingestion_id)

    generation.retrieval_results
    |> Map.take(results)
    |> Enum.reduce(%{}, fn {method, chunks}, acc ->
      evaluation = do_evaluate(chunks, chunk, question_map)
      Map.put(acc, method, evaluation)
    end)
  end

  defp do_evaluate(chunks, chunk, question_map) do
    first_hit = if Enum.any?(chunks), do: Enum.at(chunks, 0), else: nil

    chunk_found? = Enum.any?(chunks, &(&1.id == chunk.id))
    source_found? = Enum.any?(chunks, &(&1.source == chunk.source))

    chunk_rank = if(chunk_found?, do: Enum.find_index(chunks, &(&1.id == chunk.id)) + 1, else: nil)
    source_rank = if(source_found?, do: Enum.find_index(chunks, &(&1.source == chunk.source)) + 1, else: nil)

    %{
      question: question_map,
      ingestion_id: chunk.ingestion_id,
      first_hit_correct?: Map.get(first_hit, :id) == chunk.id,
      first_hit_source_correct?: Map.get(first_hit, :source) == chunk.source,
      source_found?: source_found?,
      source_rank: source_rank,
      first_hit_id: Map.get(first_hit, :id),
      total_chunks_found: length(chunks),
      chunk_found?: chunk_found?,
      chunk_rank: chunk_rank
    }
  end

  @spec batch_evaluation(String.t()) :: [evaluation()]
  @spec batch_evaluation(String.t(), batch_evaluation_opts()) ::
          [evaluation()] | {:ok, filepath()}
  def batch_evaluation(question_json_file_path, opts \\ []) do
    aggregate? = Keyword.get(opts, :aggregate, false)
    download? = Keyword.get(opts, :download, false)
    download_dir = Keyword.get(opts, :download_dir, @download_dir)
    result_types = Keyword.get(opts, :results, default_result_types(aggregate?))

    evaluation =
      question_json_file_path
      |> File.read!()
      |> Jason.decode!()
      |> Enum.map(fn %{
                       "chunk_id" => chunk_id,
                       "generation_environment_id" => generation_environment_id,
                       "question" => question
                     } ->
        evaluate(
          %{
            chunk_id: chunk_id,
            question: question,
            generation_environment_id: generation_environment_id
          },
          results: result_types
        )
      end)
      |> map_evaluation_results(result_types)

    cond do
      aggregate? ->
        Map.new(evaluation, fn {k, v} -> {k, aggregate_batch_evaluation(v)} end)

      download? && Mix.env() != :prod ->
        {:ok,
         for {result_type, evaluation_result} <- evaluation do
           {:ok, path} =
             evaluation_to_csv(evaluation_result, download_dir, evaluation_filename(result_type))

           path
         end}

      true ->
        evaluation
    end
  end

  defp default_result_types(true = _aggregate?),
    do: [:rrf_result, :fulltext_results, :semantic_results]

  defp default_result_types(false), do: [:rrf_result]

  defp evaluation_filename(result_type) do
    "evaluation_#{result_type}_#{DateTime.to_iso8601(DateTime.utc_now(), :basic)}.csv"
  end

  defp evaluation_to_csv(evaluation, download_dir, filename) do
    headers = [
      "ingestion_id",
      "generation_environment_id",
      "chunk_id",
      "question",
      "first_hit_correct?",
      "first_hit_id",
      "total_chunks_found",
      "chunk_found?",
      "chunk_rank"
    ]

    data =
      Enum.map(
        evaluation,
        &[
          &1.ingestion_id,
          &1.question.generation_environment_id,
          &1.question.chunk_id,
          &1.question.question,
          &1.first_hit_correct?,
          &1.first_hit_id,
          &1.total_chunks_found,
          &1.chunk_found?,
          &1.chunk_rank
        ]
      )

    download(download_dir, filename, NimbleCSV.RFC4180.dump_to_iodata([headers] ++ data))
  end

  defp aggregate_batch_evaluation(evaluation) do
    total = length(evaluation)
    to_ratio = fn count -> (count / total) |> Float.round(2) end

    found_chunks_ranks =
      Enum.filter(evaluation, & &1.chunk_found?) |> Enum.map(& &1.chunk_rank)

    found_sources_ranks =
      Enum.filter(evaluation, & &1.source_found?) |> Enum.map(& &1.source_rank)

    found_chunk_ratio = Enum.count(found_chunks_ranks) |> to_ratio.()
    found_source_ratio = Enum.count(found_sources_ranks) |> to_ratio.()

    first_hits_ratio = Enum.count(evaluation, & &1.first_hit_correct?) |> to_ratio.()
    first_hits_source_ratio = Enum.count(evaluation, & &1.first_hit_source_correct?) |> to_ratio.()


    %{
      question_count: total,
      first_hit_ratio: first_hits_ratio,
      found_chunk_ratio: found_chunk_ratio,
      avg_found_chunk_rank: avg(found_chunks_ranks),
      median_found_chunk_rank: median(found_chunks_ranks),
      first_hit_source_ratio: first_hits_source_ratio,
      found_source_ratio: found_source_ratio,
      avg_found_source_rank: avg(found_sources_ranks),
      median_found_source_rank: median(found_sources_ranks)
    }
  end

  defp avg(chunk_ranks) do
    round(Enum.sum(chunk_ranks) / length(chunk_ranks))
  end

  defp median(chunk_ranks) do
    middle_index = chunk_ranks |> length() |> div(2)

    chunk_ranks
    |> Enum.sort()
    |> Enum.at(middle_index)
  end

  defp map_evaluation_results(evaluation_results, result_types) do
    Enum.into(result_types, %{}, fn result_type ->
      {result_type, Enum.map(evaluation_results, & &1[result_type])}
    end)
  end
end
