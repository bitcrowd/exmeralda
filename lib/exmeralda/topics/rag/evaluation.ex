defmodule Exmeralda.Topics.Rag.Evaluation do
  @moduledoc """
  ⚠️ The generation environment needs to exist. Create it yourself or run the seeds first. ⚠️
  (with `mix seed`).

  Usage:
  1. Run the server with an iex console: `iex -S mix phx.server`
  2. Call with:
    - `Exmeralda.Topics.Rag.Evaluation.batch_question_generation(<<< INGESTION ID >>>, "1667da4f-249a-4e23-ae13-85a4efa5d1f5", download: true)`
    - `Exmeralda.Topics.Rag.Evaluation.evaluate(%{chunk_id: <<< CHUNK ID >>>, generation_environment_id: "1667da4f-249a-4e23-ae13-85a4efa5d1f5", question: <<< QUESTION >>>})`
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
          download_dir: filepath()
        ]
  @type question_opts :: [content: String.t()]
  @type evaluation :: %{
          question: question(),
          ingestion_id: Ingestion.id(),
          first_hit_correct?: boolean(),
          first_hit_id: Chunk.id(),
          total_chunks_found: pos_integer(),
          chunk_was_found?: boolean(),
          chunk_rank: pos_integer() | nil
        }

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
        where: c.ingestion_id == ^ingestion_id and not is_nil(c.embedding),
        # TODO: Well this is random, ideally we don't want to reuse always the same chunks
        # But since the LLM request is so long, it could make sense to involve Oban in the mix
        # and save the questions in a DB table.
        order_by: fragment("RANDOM()"),
        limit: ^limit
      )
      |> Repo.all()
      |> Enum.with_index()
      |> Enum.map(fn {chunk, index} ->
        Logger.info("⌛️ Generating question #{index + 1}/#{limit}")

        case do_question_generation(chunk, generation_environment_id) do
          {:ok, result} -> result
          {:error, error} -> raise error
        end
      end)

    if download? && Mix.env() != :prod do
      download(download_dir, questions_filename(ingestion), Jason.encode!(results))
    else
      results
    end
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

  defp do_question_generation(
         chunk,
         generation_environment_id,
         opts \\ []
       ) do
    content = Keyword.get(opts, :content, chunk.content)

    # TODO: Run in parallel tasks instead of serial.
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
  @spec evaluate(question()) :: evaluation()
  def evaluate(%{
        chunk_id: chunk_id,
        question: question,
        generation_environment_id: generation_environment_id
      }) do
    chunk = Repo.get!(Chunk, chunk_id)

    {chunks, _generation} =
      %{
        generation_environment_id: generation_environment_id,
        content: question
      }
      |> Chats.build_generation(chunk.ingestion_id)

    chunk_was_found = Enum.any?(chunks, &(&1.id == chunk.id))
    first_hit_id = if Enum.any?(chunks), do: Enum.at(chunks, 0).id, else: nil

    %{
      question: %{
        chunk_id: chunk_id,
        generation_environment_id: generation_environment_id,
        question: question
      },
      ingestion_id: chunk.ingestion_id,
      first_hit_correct?: first_hit_id == chunk.id,
      first_hit_id: first_hit_id,
      total_chunks_found: length(chunks),
      chunk_was_found?: chunk_was_found,
      chunk_rank:
        if(chunk_was_found, do: Enum.find_index(chunks, &(&1.id == chunk.id)) + 1, else: nil)
    }
  end

  @spec batch_evaluation(String.t()) :: [evaluation()]
  @spec batch_evaluation(String.t(), batch_evaluation_opts()) ::
          [evaluation()] | {:ok, filepath()}
  def batch_evaluation(json_file_path, opts \\ []) do
    download? = Keyword.get(opts, :download, false)
    download_dir = Keyword.get(opts, :download_dir, @download_dir)

    evaluation =
      json_file_path
      |> File.read!()
      |> Jason.decode!()
      |> Enum.map(fn %{
                       "chunk_id" => chunk_id,
                       "generation_environment_id" => generation_environment_id,
                       "question" => question
                     } ->
        evaluate(%{
          chunk_id: chunk_id,
          question: question,
          generation_environment_id: generation_environment_id
        })
      end)

    if download? && Mix.env() != :prod do
      evaluation_to_csv(evaluation, download_dir, evaluation_filename())
    else
      evaluation
    end
  end

  defp evaluation_filename do
    "evaluation_#{DateTime.to_iso8601(DateTime.utc_now(), :basic)}.csv"
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
      "chunk_was_found?",
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
          &1.chunk_was_found?,
          &1.chunk_rank
        ]
      )

    download(download_dir, filename, NimbleCSV.RFC4180.dump_to_iodata([headers] ++ data))
  end
end
