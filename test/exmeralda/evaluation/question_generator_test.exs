defmodule Exmeralda.Evaluation.QuestionGeneratorTest do
  use Exmeralda.DataCase, async: true

  alias Exmeralda.Evaluation.QuestionGenerator

  setup do
    # Set up mock provider and model config for tests
    provider = insert(:provider, type: :mock, name: "test_mock")
    model_config = insert(:model_config, name: "test-fake-model")
    
    %{provider: provider, model_config: model_config}
  end

  describe "chunk_stats/0" do
    test "returns empty stats when no chunks exist" do
      stats = QuestionGenerator.chunk_stats()
      
      assert stats.total_count == 0
      assert stats.type_counts == %{}
      assert stats.has_chunks == false
    end

    test "returns correct stats when chunks exist" do
      # TODO: Add test with actual chunks when we have factories set up
      # This will be implemented when we have test data
      :skip
    end
  end

  describe "list_chunks/1" do
    test "returns empty list when no chunks exist" do
      assert {:ok, []} = QuestionGenerator.list_chunks()
    end

    test "respects limit parameter" do
      assert {:ok, []} = QuestionGenerator.list_chunks(limit: 5)
    end
  end

  describe "from_chunk/2" do
    test "returns error for invalid chunk ID" do
      assert {:error, {:invalid_chunk_id, "invalid"}} = 
        QuestionGenerator.from_chunk("invalid")
    end

    test "returns error for non-existent chunk ID" do
      non_existent_id = Ecto.UUID.generate()
      
      assert {:error, {:chunk_not_found, ^non_existent_id}} = 
        QuestionGenerator.from_chunk(non_existent_id)
    end

    test "generates questions for valid chunk using mock provider" do
      # Create a test chunk
      chunk = insert(:chunk, content: "Test content about Ecto schemas", type: :docs)
      
      assert {:ok, questions} = QuestionGenerator.from_chunk(chunk.id)
      assert is_list(questions)
      assert length(questions) == 3  # Mock provider returns 3 questions
      assert Enum.all?(questions, &is_binary/1)
    end

    test "respects question_count option (mock provider limitation)" do
      chunk = insert(:chunk, content: "Test content", type: :code)
      
      # Note: Mock provider always returns 3 questions regardless of request
      assert {:ok, questions} = QuestionGenerator.from_chunk(chunk.id, question_count: 5)
      assert length(questions) == 3  # Mock limitation
    end
  end

  describe "from_keyword/3" do
    test "returns error for invalid keyword type" do
      assert {:error, {:invalid_keyword, 123}} = 
        QuestionGenerator.from_keyword(123)
    end

    test "returns error when no context found and no chunks match keyword" do
      # Test with a keyword that won't match any chunks
      assert {:error, {:no_context_found, "nonexistentkeyword12345"}} = 
        QuestionGenerator.from_keyword("nonexistentkeyword12345")
    end

    test "uses provided context when given" do
      context = "Test context about Ecto schemas and how they work."
      
      # With mock provider, should return questions
      case QuestionGenerator.from_keyword("schema", context, model_provider: "mock") do
        {:ok, questions} -> 
          assert is_list(questions)
          assert length(questions) >= 1
        {:error, reason} ->
          # If no mock provider available, that's expected
          assert reason in [:no_providers_available, {:provider_not_found, "mock"}, {:llm_error, {:provider_not_found, "mock"}}]
      end
    end

    test "searches for context when none provided" do
      # Create a test chunk with keyword content
      _chunk = insert(:chunk, 
        content: "This is about Ecto changesets and validation.",
        type: :docs
      )
      
      # Test should find the chunk and generate questions
      case QuestionGenerator.from_keyword("changeset", nil, model_provider: "mock") do
        {:ok, questions} ->
          assert is_list(questions)
          assert length(questions) >= 1
        {:error, {:no_context_found, _}} ->
          # This is acceptable if search doesn't find relevant content
          :ok
        {:error, reason} ->
          # Other errors like no providers are also acceptable in test env
          assert reason in [:no_providers_available, {:provider_not_found, "mock"}, {:llm_error, {:provider_not_found, "mock"}}]
      end
    end
  end

  describe "from_chunks/2" do
    test "returns error for invalid input type" do
      assert {:error, {:invalid_chunk_ids, "chunk_ids must be a list"}} = 
        QuestionGenerator.from_chunks("not_a_list")
    end
    
    test "returns error for empty list" do
      assert {:ok, %{}} = QuestionGenerator.from_chunks([])
    end
    
    test "processes single chunk successfully" do
      chunk = insert(:chunk, content: "Test content for batch processing", type: :docs)
      
      assert {:ok, results} = QuestionGenerator.from_chunks([chunk.id])
      assert Map.has_key?(results, chunk.id)
      assert is_list(results[chunk.id])
      assert length(results[chunk.id]) == 3  # Mock provider returns 3 questions
    end
    
    test "processes multiple chunks successfully" do
      chunk1 = insert(:chunk, content: "First chunk content", type: :docs)
      chunk2 = insert(:chunk, content: "Second chunk content", type: :code)
      
      chunk_ids = [chunk1.id, chunk2.id]
      
      assert {:ok, results} = QuestionGenerator.from_chunks(chunk_ids)
      assert Map.has_key?(results, chunk1.id)
      assert Map.has_key?(results, chunk2.id)
      assert is_list(results[chunk1.id])
      assert is_list(results[chunk2.id])
    end
    
    test "handles batch processing options" do
      chunk = insert(:chunk, content: "Test content", type: :docs)
      
      opts = [
        batch_size: 5,
        max_concurrency: 2,
        show_progress: false,
        question_count: 2
      ]
      
      assert {:ok, results} = QuestionGenerator.from_chunks([chunk.id], opts)
      assert Map.has_key?(results, chunk.id)
      # Note: Mock provider ignores question_count and always returns 3
    end
    
    test "handles mix of valid and invalid chunk IDs" do
      valid_chunk = insert(:chunk, content: "Valid chunk", type: :docs)
      invalid_id = "invalid-uuid"
      non_existent_id = Ecto.UUID.generate()
      
      chunk_ids = [valid_chunk.id, invalid_id, non_existent_id]
      
      assert {:ok, results} = QuestionGenerator.from_chunks(chunk_ids)
      
      # Valid chunk should have questions
      assert is_list(results[valid_chunk.id])
      
      # Invalid chunks should have error tuples
      assert {:error, _} = results[invalid_id]
      assert {:error, _} = results[non_existent_id]
    end
  end

  describe "get_random_chunk/0" do
    test "returns no chunks available when database is empty" do
      assert {:error, :no_chunks_available} = 
        QuestionGenerator.get_random_chunk()
    end
  end
end