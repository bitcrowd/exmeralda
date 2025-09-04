defmodule Exmeralda.Topics.Rag.EvaluationTest do
  use Exmeralda.DataCase
  alias Exmeralda.Topics.Rag.Evaluation

  describe "question_generation/2,3" do
    test "raises if the chunk does not exist" do
      assert_raise Ecto.NoResultsError, fn -> Evaluation.question_generation(uuid(), uuid()) end
    end

    test "errors if the chunk has no embedding" do
      ingestion = insert(:ingestion)
      chunk = insert(:chunk, ingestion: ingestion, embedding: nil)
      assert Evaluation.question_generation(chunk.id, uuid()) == {:error, :chunk_not_embedded}
    end

    test "generates a question for a given chunk id" do
      ingestion = insert(:ingestion)
      chunk = insert(:chunk, ingestion: ingestion)
      provider = insert(:provider, type: :mock)
      model_config_provider = insert(:model_config_provider, provider: provider)

      generation_environment =
        insert(:generation_environment, model_config_provider: model_config_provider)

      assert Evaluation.question_generation(chunk.id, generation_environment.id) == {
               :ok,
               %{
                 question: "This is a streaming response!",
                 chunk_id: chunk.id,
                 generation_environment_id: generation_environment.id
               }
             }

      wait_for_generation_task()
    end

    test "allows to pass a manual content" do
      ingestion = insert(:ingestion)
      chunk = insert(:chunk, ingestion: ingestion)
      provider = insert(:provider, type: :mock)
      model_config_provider = insert(:model_config_provider, provider: provider)

      generation_environment =
        insert(:generation_environment, model_config_provider: model_config_provider)

      assert Evaluation.question_generation(chunk.id, generation_environment.id,
               content: "Make the question about cookies"
             ) == {
               :ok,
               %{
                 question: "This is a streaming response!",
                 chunk_id: chunk.id,
                 generation_environment_id: generation_environment.id
               }
             }

      wait_for_generation_task()
    end
  end

  describe "batch_question_generation/2,3 with invalid data" do
    test "raises if the ingestion does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Evaluation.batch_question_generation(uuid(), uuid())
      end
    end

    test "raises if the ingestion is not ready" do
      ingestion = insert(:ingestion, state: :embedding)

      assert_raise RuntimeError, fn ->
        Evaluation.batch_question_generation(ingestion.id, uuid())
      end
    end
  end

  describe "batch_question_generation/2,3" do
    setup do
      ingestion = insert(:ingestion, state: :ready)
      first_chunk = insert(:chunk, ingestion: ingestion)
      second_chunk = insert(:chunk, ingestion: ingestion)
      insert(:chunk, ingestion: insert(:ingestion))
      insert(:chunk, ingestion: ingestion, embedding: nil)

      provider = insert(:provider, type: :mock)
      model_config_provider = insert(:model_config_provider, provider: provider)

      generation_environment =
        insert(:generation_environment, model_config_provider: model_config_provider)

      %{
        ingestion: ingestion,
        first_chunk: first_chunk,
        second_chunk: second_chunk,
        generation_environment: generation_environment
      }
    end

    test "generates a question for chunks of a given ingestion id", %{
      ingestion: ingestion,
      first_chunk: first_chunk,
      second_chunk: second_chunk,
      generation_environment: generation_environment
    } do
      result = Evaluation.batch_question_generation(ingestion.id, generation_environment.id)
      assert length(result) == 2

      assert %{
               question: "This is a streaming response!",
               chunk_id: first_chunk.id,
               generation_environment_id: generation_environment.id
             } in result

      assert %{
               question: "This is a streaming response!",
               chunk_id: second_chunk.id,
               generation_environment_id: generation_environment.id
             } in result

      wait_for_generation_task()
    end

    test "accepts a limit parameter", %{
      ingestion: ingestion,
      generation_environment: generation_environment
    } do
      assert [
               %{
                 question: "This is a streaming response!"
               }
             ] =
               Evaluation.batch_question_generation(ingestion.id, generation_environment.id,
                 limit: 1
               )

      wait_for_generation_task()
    end

    @tag :tmp_dir
    test "accepts a download parameter", %{
      ingestion: ingestion,
      generation_environment: generation_environment,
      first_chunk: first_chunk,
      second_chunk: second_chunk,
      tmp_dir: tmp_dir
    } do
      assert {:ok, filepath} =
               Evaluation.batch_question_generation(ingestion.id, generation_environment.id,
                 download: true,
                 download_path: tmp_dir
               )

      assert String.ends_with?(filepath, ".json")
      wait_for_generation_task()

      result = File.read!(filepath) |> Jason.decode!()

      assert length(result) == 2

      assert %{
               "question" => "This is a streaming response!",
               "chunk_id" => first_chunk.id,
               "generation_environment_id" => generation_environment.id
             } in result

      assert %{
               "question" => "This is a streaming response!",
               "chunk_id" => second_chunk.id,
               "generation_environment_id" => generation_environment.id
             } in result
    end
  end

  describe "evaluate/1" do
    test "raises if the chunk does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Evaluation.evaluate(%{chunk_id: uuid(), generation_environment_id: uuid(), question: ""})
      end
    end

    test "returns stats about the retrieval quality" do
      ingestion = insert(:ingestion)
      chunk = insert(:chunk, ingestion: ingestion, content: "The cookie jar does not exist")

      generation_environment = insert(:generation_environment)

      assert Evaluation.evaluate(%{
               chunk_id: chunk.id,
               generation_environment_id: generation_environment.id,
               question: "Where is the cookie jar?"
             }) == %{
               first_hit_correct?: true,
               total_chunks_found: 1,
               chunk_was_found?: true,
               chunk_rank: 1
             }
    end
  end
end
