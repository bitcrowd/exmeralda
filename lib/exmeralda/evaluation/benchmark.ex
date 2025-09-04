defmodule Exmeralda.Evaluation.Benchmark do
  @moduledoc """
  Benchmarking utilities for question generation performance comparison.
  
  This module provides tools to compare different model providers and measure
  performance metrics such as response time, quality, and consistency.
  """
  
  alias Exmeralda.Evaluation.QuestionGenerator
  require Logger
  
  @doc """
  Runs a comprehensive benchmark comparing different providers and models.
  
  ## Options
  
  - `:chunk_count` - Number of chunks to test with (default: 5)
  - `:providers` - List of provider/model combinations to test
  - `:output_format` - `:table` or `:json` (default: `:table`)
  
  ## Examples
  
      # Basic benchmark with default settings
      Benchmark.run_comparison()
      
      # Custom benchmark
      Benchmark.run_comparison(
        chunk_count: 3,
        providers: [
          %{provider: "mock", model: "llm-fake-model"},
          %{provider: "ollama_ai", model: "llama3.2:3b"}
        ]
      )
  """
  @spec run_comparison(keyword()) :: :ok | {:error, term()}
  def run_comparison(opts \\ []) do
    chunk_count = Keyword.get(opts, :chunk_count, 5)
    output_format = Keyword.get(opts, :output_format, :table)
    
    providers = Keyword.get(opts, :providers, [
      %{provider: "mock", model: "llm-fake-model"},
      %{provider: "ollama_ai", model: "llama3.2:3b"}
    ])
    
    Logger.info("Starting benchmark with #{chunk_count} chunks across #{length(providers)} provider configurations")
    
    # Get random chunks for testing
    case get_test_chunks(chunk_count) do
      {:ok, chunks} ->
        results = run_provider_benchmarks(chunks, providers)
        display_results(results, output_format)
        :ok
        
      {:error, reason} ->
        Logger.error("Failed to get test chunks: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Measures response time for a single question generation request.
  
  ## Examples
  
      Benchmark.measure_latency("chunk-uuid", provider: "mock")
      # => {:ok, %{response_time_ms: 45, questions: [...]}}
  """
  @spec measure_latency(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def measure_latency(chunk_id, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)
    
    case QuestionGenerator.from_chunk(chunk_id, opts) do
      {:ok, questions} ->
        end_time = System.monotonic_time(:millisecond)
        response_time = end_time - start_time
        
        {:ok, %{
          response_time_ms: response_time,
          questions: questions,
          question_count: length(questions)
        }}
        
      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)
        response_time = end_time - start_time
        
        {:error, %{
          reason: reason,
          response_time_ms: response_time
        }}
    end
  end
  
  @doc """
  Evaluates question quality based on various metrics.
  
  Returns a quality score from 1-10 based on:
  - Length and complexity
  - Technical specificity
  - Question variety
  
  Note: This is a basic heuristic evaluation. For production use,
  consider implementing more sophisticated quality metrics.
  """
  @spec evaluate_quality([String.t()]) :: map()
  def evaluate_quality(questions) do
    length_score = evaluate_length_variety(questions)
    technical_score = evaluate_technical_content(questions)
    variety_score = evaluate_question_variety(questions)
    
    overall_score = (length_score + technical_score + variety_score) / 3
    
    %{
      overall_score: Float.round(overall_score, 1),
      length_variety: length_score,
      technical_content: technical_score,
      question_variety: variety_score,
      question_count: length(questions)
    }
  end
  
  # Private Functions
  
  defp get_test_chunks(count) do
    case QuestionGenerator.list_chunks(limit: count * 2) do
      {:ok, chunks} when length(chunks) == 0 ->
        {:error, {:no_chunks_found, "No chunks available for testing"}}
        
      {:ok, chunks} ->
        # Select a diverse mix of chunk types
        selected = 
          chunks
          |> Enum.take(count)
          |> Enum.map(&%{id: &1.id, type: &1.type, source: &1.source})
        
        {:ok, selected}
        
      error -> error
    end
  end
  
  defp run_provider_benchmarks(chunks, providers) do
    Enum.flat_map(providers, fn provider_config ->
      Logger.info("Testing provider: #{provider_config.provider}/#{provider_config.model}")
      
      Enum.map(chunks, fn chunk ->
        opts = [
          model_provider: provider_config.provider,
          model_config: provider_config.model
        ]
        
        case measure_latency(chunk.id, opts) do
          {:ok, result} ->
            quality = evaluate_quality(result.questions)
            
            %{
              chunk_id: chunk.id,
              chunk_type: chunk.type,
              provider: provider_config.provider,
              model: provider_config.model,
              status: :success,
              response_time_ms: result.response_time_ms,
              question_count: result.question_count,
              quality_score: quality.overall_score,
              quality_details: quality
            }
            
          {:error, error_result} ->
            %{
              chunk_id: chunk.id,
              chunk_type: chunk.type,
              provider: provider_config.provider,
              model: provider_config.model,
              status: :error,
              response_time_ms: error_result.response_time_ms,
              error_reason: error_result.reason
            }
        end
      end)
    end)
  end
  
  defp display_results(results, :table) do
    IO.puts("\n📊 Question Generation Benchmark Results")
    IO.puts("=" <> String.duplicate("=", 70))
    
    # Group by provider for summary
    grouped = Enum.group_by(results, &{&1.provider, &1.model})
    
    Enum.each(grouped, fn {{provider, model}, provider_results} ->
      successful = Enum.filter(provider_results, &(&1.status == :success))
      failed = Enum.filter(provider_results, &(&1.status == :error))
      
      IO.puts("\n🔧 Provider: #{provider}/#{model}")
      IO.puts("   Success Rate: #{length(successful)}/#{length(provider_results)} (#{success_percentage(successful, provider_results)}%)")
      
      if length(successful) > 0 do
        avg_time = successful |> Enum.map(&(&1.response_time_ms)) |> Enum.sum() |> div(length(successful))
        avg_quality = successful |> Enum.map(&(&1.quality_score)) |> Enum.sum() |> then(&(&1 / length(successful))) |> Float.round(1)
        
        IO.puts("   Avg Response Time: #{avg_time}ms")
        IO.puts("   Avg Quality Score: #{avg_quality}/10")
        
        # Show individual results
        Enum.each(successful, fn result ->
          IO.puts("   • #{String.slice(result.chunk_id, 0, 8)}... (#{result.chunk_type}): #{result.response_time_ms}ms, Quality: #{result.quality_score}/10")
        end)
      end
      
      if length(failed) > 0 do
        IO.puts("   ❌ Failed chunks:")
        Enum.each(failed, fn result ->
          IO.puts("   • #{String.slice(result.chunk_id, 0, 8)}...: #{inspect(result.error_reason)}")
        end)
      end
    end)
    
    IO.puts("\n💡 Recommendations:")
    recommend_best_provider(results)
  end
  
  defp display_results(results, :json) do
    summary = %{
      total_tests: length(results),
      successful_tests: Enum.count(results, &(&1.status == :success)),
      providers_tested: results |> Enum.map(&{&1.provider, &1.model}) |> Enum.uniq(),
      results: results
    }
    
    IO.puts(Jason.encode!(summary, pretty: true))
  end
  
  defp success_percentage(successful, total) do
    if length(total) > 0 do
      Float.round(length(successful) / length(total) * 100, 1)
    else
      0
    end
  end
  
  defp recommend_best_provider(results) do
    successful = Enum.filter(results, &(&1.status == :success))
    
    if length(successful) > 0 do
      # Find best by quality
      best_quality = Enum.max_by(successful, &(&1.quality_score))
      IO.puts("   🏆 Best Quality: #{best_quality.provider}/#{best_quality.model} (#{best_quality.quality_score}/10)")
      
      # Find fastest
      fastest = Enum.min_by(successful, &(&1.response_time_ms))
      IO.puts("   ⚡ Fastest: #{fastest.provider}/#{fastest.model} (#{fastest.response_time_ms}ms)")
      
      # Find best balance
      balanced = 
        successful
        |> Enum.map(fn r -> 
          # Normalize response time (lower is better) and quality (higher is better)
          normalized_time = 1000 / max(r.response_time_ms, 1)  # Avoid division by zero
          balance_score = (normalized_time + r.quality_score * 100) / 2
          Map.put(r, :balance_score, balance_score)
        end)
        |> Enum.max_by(&(&1.balance_score))
        
      IO.puts("   ⚖️  Best Balance: #{balanced.provider}/#{balanced.model}")
    else
      IO.puts("   ⚠️  No successful tests to analyze")
    end
  end
  
  # Quality evaluation heuristics
  
  defp evaluate_length_variety(questions) do
    if length(questions) == 0, do: 0
    
    lengths = Enum.map(questions, &String.length/1)
    avg_length = if length(lengths) > 0, do: Enum.sum(lengths) / length(lengths), else: 0
    
    # Score based on reasonable question length (50-150 chars is good)
    cond do
      avg_length < 20 -> 2
      avg_length < 50 -> 5
      avg_length < 150 -> 8
      avg_length < 200 -> 6
      true -> 3
    end
  end
  
  defp evaluate_technical_content(questions) do
    technical_terms = [
      "function", "method", "class", "module", "variable", "parameter",
      "return", "error", "exception", "database", "query", "schema",
      "changeset", "repo", "ecto", "elixir", "phoenix", "struct"
    ]
    
    technical_score = 
      questions
      |> Enum.map(fn question ->
        lower_question = String.downcase(question)
        matches = Enum.count(technical_terms, &String.contains?(lower_question, &1))
        min(matches, 3)  # Cap at 3 points per question
      end)
      |> Enum.sum()
      |> min(10)  # Cap total score at 10
    
    max(technical_score, 1)
  end
  
  defp evaluate_question_variety(questions) do
    if length(questions) == 0, do: 5
    if length(questions) <= 1, do: 5
    
    # Look for variety in question starters
    starters = 
      questions
      |> Enum.map(fn q -> 
        q
        |> String.downcase()
        |> String.split()
        |> List.first()
      end)
      |> Enum.uniq()
    
    variety_ratio = if length(questions) > 0, do: length(starters) / length(questions), else: 0
    
    cond do
      variety_ratio >= 0.8 -> 10  # Very diverse
      variety_ratio >= 0.6 -> 8   # Good variety
      variety_ratio >= 0.4 -> 6   # Some variety
      variety_ratio >= 0.2 -> 4   # Limited variety
      true -> 2                   # Poor variety
    end
  end
end