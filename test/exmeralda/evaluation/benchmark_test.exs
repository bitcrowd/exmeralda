defmodule Exmeralda.Evaluation.BenchmarkTest do
  use Exmeralda.DataCase, async: true

  alias Exmeralda.Evaluation.Benchmark

  setup do
    # Set up mock provider and model config for tests
    provider = insert(:provider, type: :mock, name: "test_mock")
    model_config = insert(:model_config, name: "test-fake-model")
    
    %{provider: provider, model_config: model_config}
  end

  describe "measure_latency/2" do
    test "measures response time for valid chunk" do
      chunk = insert(:chunk, content: "Test content for latency measurement", type: :docs)
      
      assert {:ok, result} = Benchmark.measure_latency(chunk.id)
      assert is_integer(result.response_time_ms)
      assert result.response_time_ms >= 0
      assert is_list(result.questions)
      assert result.question_count == length(result.questions)
    end
    
    test "measures response time for invalid chunk" do
      invalid_id = "invalid-uuid"
      
      assert {:error, result} = Benchmark.measure_latency(invalid_id)
      assert is_integer(result.response_time_ms)
      assert result.response_time_ms >= 0
      assert result.reason == {:invalid_chunk_id, "invalid-uuid"}
    end
    
    test "accepts provider options" do
      chunk = insert(:chunk, content: "Test content", type: :docs)
      opts = [model_provider: "test_mock", model_config: "test-fake-model"]
      
      # Should either succeed with questions or fail with provider error
      case Benchmark.measure_latency(chunk.id, opts) do
        {:ok, result} ->
          assert is_list(result.questions)
        {:error, result} ->
          assert result.reason == {:llm_error, {:provider_not_found, "test_mock"}}
          assert is_integer(result.response_time_ms)
      end
    end
  end

  describe "evaluate_quality/1" do
    test "evaluates empty question list" do
      result = Benchmark.evaluate_quality([])
      assert result.overall_score > 0  # Will be > 0 due to minimum scores
      assert result.question_count == 0
      assert result.length_variety >= 0
      assert result.technical_content >= 1
      assert is_number(result.question_variety)
    end
    
    test "evaluates single question" do
      questions = ["What is the purpose of the Ecto.Repo.delete/2 function in database operations?"]
      
      result = Benchmark.evaluate_quality(questions)
      assert result.overall_score > 0
      assert result.question_count == 1
      assert is_number(result.length_variety)
      assert is_number(result.technical_content)
      assert is_number(result.question_variety)
    end
    
    test "evaluates multiple questions with variety" do
      questions = [
        "How does Ecto handle database transactions?",
        "What are the benefits of using changesets?", 
        "Can you explain the purpose of Ecto schemas?"
      ]
      
      result = Benchmark.evaluate_quality(questions)
      assert result.overall_score > 0
      assert result.question_count == 3
      # Should score well for variety since all questions start differently
      assert result.question_variety >= 8
    end
    
    test "penalizes poor question variety" do
      questions = [
        "How does this work?",
        "How does that work?",
        "How does everything work?"
      ]
      
      result = Benchmark.evaluate_quality(questions)
      # Should score poorly for variety since all questions start with "how"
      assert result.question_variety < 5
    end
    
    test "rewards technical content" do
      technical_questions = [
        "How do you implement changeset validation in Ecto schemas?",
        "What is the purpose of the Repo.delete/2 function?",
        "How does the database query optimization work?"
      ]
      
      generic_questions = [
        "How does this work?",
        "What is the purpose of this thing?",
        "How does the optimization work?"
      ]
      
      technical_result = Benchmark.evaluate_quality(technical_questions)
      generic_result = Benchmark.evaluate_quality(generic_questions)
      
      assert technical_result.technical_content > generic_result.technical_content
    end
  end

  describe "run_comparison/1" do
    test "returns error when no chunks available" do
      # Clear any existing chunks
      Repo.delete_all(Exmeralda.Topics.Chunk)
      
      result = Benchmark.run_comparison(chunk_count: 1)
      assert result == {:error, {:no_chunks_found, "No chunks available for testing"}}
    end
    
    test "runs comparison with available chunks" do
      # Create test chunks
      _chunk1 = insert(:chunk, content: "Test content 1", type: :docs)
      _chunk2 = insert(:chunk, content: "Test content 2", type: :code)
      
      # Run with small chunk count and simple providers
      providers = [%{provider: "mock", model: "test-fake-model"}]
      
      assert :ok = Benchmark.run_comparison(
        chunk_count: 1, 
        providers: providers,
        output_format: :table
      )
    end
    
    test "handles provider configuration errors gracefully" do
      _chunk = insert(:chunk, content: "Test content", type: :docs)
      
      # Use non-existent provider
      providers = [%{provider: "nonexistent", model: "fake"}]
      
      assert :ok = Benchmark.run_comparison(
        chunk_count: 1,
        providers: providers,
        output_format: :table
      )
    end
  end

  describe "quality evaluation heuristics" do
    test "length variety scoring" do
      # Test with different length patterns
      short_questions = ["What?", "How?", "Why?"]
      medium_questions = ["How does Ecto handle database operations?", "What are changesets used for?", "Why use Ecto over raw SQL?"]
      long_questions = ["Can you provide a detailed explanation of how Ecto's changeset validation system works in conjunction with database constraints and foreign key relationships while maintaining data integrity?"] 
      
      short_result = Benchmark.evaluate_quality(short_questions)
      medium_result = Benchmark.evaluate_quality(medium_questions)
      long_result = Benchmark.evaluate_quality(long_questions)
      
      # Medium length should score better than short
      assert medium_result.length_variety >= short_result.length_variety
      # Long might also score well if within reasonable range
      assert medium_result.overall_score > short_result.overall_score
    end
    
    test "technical content detection" do
      # Test technical term recognition
      technical_terms = ["function", "changeset", "schema", "database", "query", "repo"]
      
      questions_with_tech = technical_terms |> Enum.map(&"How does #{&1} work in Elixir?")
      questions_without_tech = ["How does this work?", "What is that thing?", "Why do we use it?"]
      
      tech_result = Benchmark.evaluate_quality(questions_with_tech)
      non_tech_result = Benchmark.evaluate_quality(questions_without_tech)
      
      assert tech_result.technical_content > non_tech_result.technical_content
    end
  end
end