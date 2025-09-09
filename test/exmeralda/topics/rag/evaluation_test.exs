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
                 download_dir: tmp_dir
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
               ingestion_id: ingestion.id,
               question: %{
                 question: "Where is the cookie jar?",
                 chunk_id: chunk.id,
                 generation_environment_id: generation_environment.id
               },
               first_hit_correct?: true,
               first_hit_id: chunk.id,
               total_chunks_found: 1,
               chunk_was_found?: true,
               chunk_rank: 1
             }
    end
  end

  @fixture_file File.cwd!() |> Path.join("test/support/fixtures/questions.json")
  describe "batch_evaluation/1,2" do
    setup do
      ingestion = insert(:ingestion, state: :ready, id: "db4e4dc9-43c5-44be-9521-58a8785071ab")
      insert(:chunk, ingestion: ingestion, id: "79c9dff1-322c-4ddc-94b5-be49c76931f2")
      insert(:chunk, ingestion: ingestion, id: "143b7836-d7a0-46df-8398-3d36894d8b58")
      insert(:generation_environment, id: "1667da4f-249a-4e23-ae13-85a4efa5d1f5")

      :ok
    end

    test "runs the evaluation for the questions in a json" do
      assert [
               %{
                 question: %{
                   question:
                     "I’ve added a support notice to my README: `# support: available for a fee`. Can I offer a warranty or indemnity to customers under Apache 2.0, and what responsibilities do I need to assume to stay compliant?",
                   chunk_id: "79c9dff1-322c-4ddc-94b5-be49c76931f2",
                   generation_environment_id: "1667da4f-249a-4e23-ae13-85a4efa5d1f5"
                 },
                 ingestion_id: "db4e4dc9-43c5-44be-9521-58a8785071ab",
                 first_hit_correct?: _,
                 first_hit_id: _,
                 total_chunks_found: 2,
                 chunk_was_found?: true,
                 chunk_rank: _
               },
               %{
                 question: %{
                   question:
                     "I need to get Carbonite’s default audit trail prefix in my Phoenix app. I’ve called  \n`Carbonite.default_prefix()` but I’m not sure what it actually returns. How can I retrieve the default audit trail prefix?",
                   chunk_id: "143b7836-d7a0-46df-8398-3d36894d8b58",
                   generation_environment_id: "1667da4f-249a-4e23-ae13-85a4efa5d1f5"
                 },
                 ingestion_id: "db4e4dc9-43c5-44be-9521-58a8785071ab",
                 first_hit_correct?: _,
                 first_hit_id: _,
                 total_chunks_found: 2,
                 chunk_was_found?: true,
                 chunk_rank: _
               }
             ] = Evaluation.batch_evaluation(@fixture_file)
    end

    @tag :tmp_dir
    test "accepts a download optional parameter", %{tmp_dir: tmp_dir} do
      assert {:ok, filepath} =
               Evaluation.batch_evaluation(@fixture_file, download: true, download_dir: tmp_dir)

      assert String.ends_with?(filepath, ".csv")
      result = File.read!(filepath)

      assert result =~
               "ingestion_id,generation_environment_id,chunk_id,question,first_hit_correct?,first_hit_id,total_chunks_found,chunk_was_found?,chunk_rank"
    end
  end
end
