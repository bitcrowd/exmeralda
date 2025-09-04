defmodule Mix.Tasks.Exmeralda.GenerateQuestions do
  @moduledoc """
  Generate evaluation questions from chunks in the database.

  This task generates questions from chunks that can be used to evaluate
  the retrieval performance of the RAG system.

  ## Usage

      # Generate questions from a specific chunk
      mix exmeralda.generate_questions --chunk-id UUID

      # Generate questions from a random chunk
      mix exmeralda.generate_questions --random

      # Generate questions from multiple random chunks
      mix exmeralda.generate_questions --random --count 5

      # Generate questions with specific options
      mix exmeralda.generate_questions --chunk-id UUID --questions 5

      # List available chunks
      mix exmeralda.generate_questions --list

      # Show chunk statistics
      mix exmeralda.generate_questions --stats

  ## Options

    * `--chunk-id` - UUID of specific chunk to generate questions for
    * `--chunk-ids` - Comma-separated list of chunk UUIDs for batch processing
    * `--keyword` - Generate questions based on a keyword with automatic context retrieval
    * `--context` - Provide custom context for keyword-based generation
    * `--random` - Use a random chunk from the database  
    * `--count` - Number of chunks to process (when using --random)
    * `--questions` - Number of questions to generate per chunk (default: 3)
    * `--provider` - LLM provider to use (e.g., "ollama_ai", "mock")
    * `--model` - Model config to use (e.g., "llama3.2:latest", "qwen25-coder-32b")
    * `--library` - Filter chunks by library name
    * `--type` - Filter chunks by type (:code or :docs)
    * `--batch-size` - Number of chunks to process per batch (default: 10)
    * `--max-concurrency` - Maximum concurrent LLM requests (default: 3)
    * `--show-progress` - Show progress during batch processing
    * `--list` - List available chunks (paginated)
    * `--list-models` - List available providers and model configs
    * `--stats` - Show chunk statistics
    * `--benchmark` - Run performance comparison between providers
    * `--benchmark-count` - Number of chunks to use in benchmark (default: 5)
    * `--help` - Show this help

  ## Examples

      # Generate 5 questions from a specific chunk
      mix exmeralda.generate_questions --chunk-id a1b2c3d4-e5f6-7890-abcd-ef1234567890 --questions 5

      # Generate questions from 3 random code chunks with specific provider
      mix exmeralda.generate_questions --random --count 3 --type code --provider ollama_ai

      # Use a specific model for question generation
      mix exmeralda.generate_questions --random --provider ollama_ai --model qwen25-coder-32b

      # Generate questions based on a keyword
      mix exmeralda.generate_questions --keyword "changeset" --questions 4

      # Generate questions with custom context
      mix exmeralda.generate_questions --keyword "validation" --context "Custom context about validations"

      # Batch process multiple chunks with progress reporting
      mix exmeralda.generate_questions --chunk-ids "uuid1,uuid2,uuid3" --show-progress

      # Batch process with custom concurrency and batch size
      mix exmeralda.generate_questions --chunk-ids "uuid1,uuid2,uuid3" --batch-size 5 --max-concurrency 2

      # List first 10 chunks from ecto library
      mix exmeralda.generate_questions --list --library ecto
      
      # Run performance benchmark comparing providers
      mix exmeralda.generate_questions --benchmark --benchmark-count 3
  """

  use Mix.Task
  alias Exmeralda.Evaluation.QuestionGenerator
  alias Exmeralda.Evaluation.Benchmark
  require Logger

  @shortdoc "Generate evaluation questions from chunks"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _args, invalid} =
      OptionParser.parse(args,
        strict: [
          chunk_id: :string,
          chunk_ids: :string,
          keyword: :string,
          context: :string,
          random: :boolean,
          count: :integer,
          questions: :integer,
          provider: :string,
          model: :string,
          library: :string,
          type: :string,
          list: :boolean,
          list_models: :boolean,
          stats: :boolean,
          benchmark: :boolean,
          benchmark_count: :integer,
          help: :boolean,
          batch_size: :integer,
          max_concurrency: :integer,
          show_progress: :boolean
        ]
      )

    if length(invalid) > 0 do
      Mix.shell().error("Invalid options: #{inspect(invalid)}")
      show_help()
      System.halt(1)
    end

    cond do
      opts[:help] -> 
        show_help()
      
      opts[:stats] -> 
        show_stats()
      
      opts[:list] -> 
        show_chunks(opts)
      
      opts[:list_models] -> 
        show_models()
      
      opts[:benchmark] -> 
        run_benchmark(opts)
      
      opts[:chunk_id] -> 
        generate_from_chunk_id(opts[:chunk_id], opts)
      
      opts[:chunk_ids] -> 
        generate_from_chunk_ids(opts[:chunk_ids], opts)
      
      opts[:keyword] -> 
        generate_from_keyword(opts[:keyword], opts)
      
      opts[:random] -> 
        generate_from_random_chunks(opts)
      
      true -> 
        Mix.shell().error("No action specified. Use --help to see available options.")
        System.halt(1)
    end
  end

  defp show_help do
    Mix.shell().info(@moduledoc)
  end

  defp show_stats do
    Mix.shell().info("Fetching chunk statistics...")
    
    stats = QuestionGenerator.chunk_stats()
    
    Mix.shell().info("""
    
    📊 Chunk Statistics:
    ==================
    Total chunks: #{stats.total_count}
    Has chunks: #{stats.has_chunks}
    
    By type:
    #{format_type_counts(stats.type_counts)}
    """)
  end

  defp format_type_counts(type_counts) do
    type_counts
    |> Enum.map(fn {type, count} -> "  #{type}: #{count}" end)
    |> Enum.join("\n")
  end

  defp show_models do
    Mix.shell().info("🔧 Available Providers and Model Configs:")
    Mix.shell().info("=========================================")
    
    providers = Exmeralda.Repo.all(Exmeralda.LLM.Provider)
    model_configs = Exmeralda.Repo.all(Exmeralda.LLM.ModelConfig)
    
    Mix.shell().info("\\n📡 Providers:")
    if Enum.empty?(providers) do
      Mix.shell().info("  No providers available")
    else
      Enum.each(providers, fn provider ->
        Mix.shell().info("  • #{provider.name} (#{provider.type})")
      end)
    end
    
    Mix.shell().info("\\n🤖 Model Configs:")
    if Enum.empty?(model_configs) do
      Mix.shell().info("  No model configs available")
    else
      Enum.each(model_configs, fn config ->
        Mix.shell().info("  • #{config.name}")
      end)
    end
    
    Mix.shell().info("\\n💡 Usage Examples:")
    if not Enum.empty?(providers) and not Enum.empty?(model_configs) do
      provider = hd(providers)
      model = hd(model_configs)
      Mix.shell().info("  mix exmeralda.generate_questions --random --provider #{provider.name}")
      Mix.shell().info("  mix exmeralda.generate_questions --random --model #{model.name}")
      Mix.shell().info("  mix exmeralda.generate_questions --random --provider #{provider.name} --model #{model.name}")
    end
  end

  defp show_chunks(opts) do
    filters = 
      []
      |> maybe_add_filter(:library, opts[:library])
      |> maybe_add_filter(:type, parse_type(opts[:type]))
      |> Keyword.put(:limit, 10) # Default pagination

    case QuestionGenerator.list_chunks(filters) do
      {:ok, chunks} ->
        Mix.shell().info("📋 Available chunks (showing first #{length(chunks)}):")
        Mix.shell().info("")
        
        Enum.each(chunks, fn chunk ->
          library_name = get_library_name(chunk)
          Mix.shell().info("• #{chunk.id}")
          Mix.shell().info("  Type: #{chunk.type}")
          Mix.shell().info("  Library: #{library_name}")
          Mix.shell().info("  Source: #{chunk.source}")
          Mix.shell().info("  Content: #{String.slice(chunk.content, 0, 80)}...")
          Mix.shell().info("")
        end)
        
      {:error, reason} ->
        Mix.shell().error("Error listing chunks: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp generate_from_chunk_id(chunk_id, opts) do
    question_count = opts[:questions] || 3
    generation_opts = build_generation_opts(opts, question_count)
    
    provider_info = format_provider_info(opts)
    Mix.shell().info("🔍 Generating #{question_count} questions from chunk #{chunk_id}#{provider_info}...")
    
    case QuestionGenerator.from_chunk(chunk_id, generation_opts) do
      {:ok, questions} ->
        Mix.shell().info("✅ Successfully generated #{length(questions)} questions:")
        Mix.shell().info("")
        
        Enum.with_index(questions, 1)
        |> Enum.each(fn {question, index} ->
          Mix.shell().info("#{index}. #{question}")
        end)
        
      {:error, reason} ->
        Mix.shell().error("❌ Error generating questions: #{format_error(reason)}")
        System.halt(1)
    end
  end

  defp generate_from_chunk_ids(chunk_ids_string, opts) do
    question_count = opts[:questions] || 3
    generation_opts = build_generation_opts(opts, question_count)
    
    # Add batch processing options
    generation_opts = 
      generation_opts
      |> maybe_add_batch_option(:batch_size, opts[:batch_size])
      |> maybe_add_batch_option(:max_concurrency, opts[:max_concurrency])
      |> maybe_add_batch_option(:show_progress, opts[:show_progress])
    
    # Parse comma-separated chunk IDs
    chunk_ids = 
      chunk_ids_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    
    if length(chunk_ids) == 0 do
      Mix.shell().error("❌ No valid chunk IDs provided")
      System.halt(1)
    end
    
    provider_info = format_provider_info(opts)
    Mix.shell().info("🔄 Batch processing #{length(chunk_ids)} chunks#{provider_info}...")
    
    case QuestionGenerator.from_chunks(chunk_ids, generation_opts) do
      {:ok, results} ->
        Mix.shell().info("✅ Batch processing completed!")
        Mix.shell().info("")
        
        # Display results
        Enum.each(results, fn {chunk_id, result} ->
          Mix.shell().info("📄 Chunk: #{chunk_id}")
          
          case result do
            questions when is_list(questions) ->
              Mix.shell().info("   ✅ Generated #{length(questions)} questions:")
              Enum.with_index(questions, 1)
              |> Enum.each(fn {question, index} ->
                Mix.shell().info("      #{index}. #{question}")
              end)
              
            {:error, reason} ->
              Mix.shell().info("   ❌ Error: #{format_error(reason)}")
          end
          
          Mix.shell().info("")
        end)
        
        # Summary statistics
        successful = results |> Map.values() |> Enum.count(&is_list/1)
        failed = length(chunk_ids) - successful
        Mix.shell().info("📊 Summary: #{successful} successful, #{failed} failed")
        
      {:error, reason} ->
        Mix.shell().error("❌ Batch processing error: #{format_error(reason)}")
        System.halt(1)
    end
  end

  defp generate_from_random_chunks(opts) do
    count = opts[:count] || 1
    question_count = opts[:questions] || 3
    generation_opts = build_generation_opts(opts, question_count)
    
    provider_info = format_provider_info(opts)
    Mix.shell().info("🎲 Generating questions from #{count} random chunk(s)#{provider_info}...")
    
    filters = 
      []
      |> maybe_add_filter(:library, opts[:library])
      |> maybe_add_filter(:type, parse_type(opts[:type]))

    1..count
    |> Enum.each(fn index ->
      case get_random_filtered_chunk(filters) do
        {:ok, chunk} ->
          Mix.shell().info("")
          Mix.shell().info("📄 Chunk #{index}/#{count}: #{chunk.id}")
          Mix.shell().info("   Library: #{get_library_name(chunk)}")
          Mix.shell().info("   Source: #{chunk.source}")
          Mix.shell().info("   Type: #{chunk.type}")
          
          case QuestionGenerator.from_chunk(chunk.id, generation_opts) do
            {:ok, questions} ->
              Mix.shell().info("   ✅ Generated #{length(questions)} questions:")
              
              Enum.with_index(questions, 1)
              |> Enum.each(fn {question, qindex} ->
                Mix.shell().info("      #{qindex}. #{question}")
              end)
              
            {:error, reason} ->
              Mix.shell().error("   ❌ Error: #{format_error(reason)}")
          end
          
        {:error, :no_chunks_available} ->
          Mix.shell().error("❌ No chunks available with the specified filters.")
          System.halt(1)
          
        {:error, reason} ->
          Mix.shell().error("❌ Error getting random chunk: #{inspect(reason)}")
          System.halt(1)
      end
    end)
  end

  defp get_random_filtered_chunk([]) do
    QuestionGenerator.get_random_chunk()
  end
  
  defp get_random_filtered_chunk(filters) do
    case QuestionGenerator.list_chunks(filters ++ [limit: 100]) do
      {:ok, []} -> {:error, :no_chunks_available}
      {:ok, chunks} -> {:ok, Enum.random(chunks)}
      error -> error
    end
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, key, value), do: Keyword.put(filters, key, value)
  
  defp maybe_add_batch_option(opts, _key, nil), do: opts
  defp maybe_add_batch_option(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_type(nil), do: nil
  defp parse_type("code"), do: :code
  defp parse_type("docs"), do: :docs
  defp parse_type(type), do: String.to_atom(type)

  defp get_library_name(chunk) do
    case chunk do
      %{ingestion: %{library: %{name: name}}} -> name
      %{library: %{name: name}} -> name
      _ -> "Unknown"
    end
  end

  defp build_generation_opts(opts, question_count) do
    generation_opts = [question_count: question_count]
    
    generation_opts = 
      if opts[:provider], do: Keyword.put(generation_opts, :model_provider, opts[:provider]), else: generation_opts
    
    generation_opts = 
      if opts[:model], do: Keyword.put(generation_opts, :model_config, opts[:model]), else: generation_opts
    
    generation_opts
  end

  defp format_provider_info(opts) do
    case {opts[:provider], opts[:model]} do
      {nil, nil} -> ""
      {provider, nil} -> " (using #{provider})"
      {nil, model} -> " (using #{model})"
      {provider, model} -> " (using #{provider}/#{model})"
    end
  end

  defp generate_from_keyword(keyword, opts) do
    question_count = opts[:questions] || 3
    generation_opts = build_generation_opts(opts, question_count)
    context = opts[:context]  # Optional custom context
    
    provider_info = format_provider_info(opts)
    Mix.shell().info("🔍 Generating #{question_count} questions for keyword '#{keyword}'#{provider_info}...")
    
    if context do
      Mix.shell().info("📝 Using provided context (#{String.length(context)} chars)")
    else
      Mix.shell().info("🔎 Searching for context chunks containing '#{keyword}'...")
    end
    
    case QuestionGenerator.from_keyword(keyword, context, generation_opts) do
      {:ok, questions} ->
        Mix.shell().info("✅ Successfully generated #{length(questions)} questions:")
        Mix.shell().info("")
        
        Enum.with_index(questions, 1)
        |> Enum.each(fn {question, index} ->
          Mix.shell().info("#{index}. #{question}")
        end)
        
      {:error, reason} ->
        Mix.shell().error("❌ Error generating questions: #{format_error(reason)}")
        System.halt(1)
    end
  end

  defp run_benchmark(opts) do
    chunk_count = opts[:benchmark_count] || 5
    Mix.shell().info("🚀 Running benchmark with #{chunk_count} chunks...")
    
    providers = [
      %{provider: "mock", model: "llm-fake-model"},
      %{provider: "ollama_ai", model: "llama3.2:3b"}
    ]
    
    case Benchmark.run_comparison(chunk_count: chunk_count, providers: providers) do
      :ok ->
        Mix.shell().info("\n✅ Benchmark completed successfully!")
        
      {:error, reason} ->
        Mix.shell().error("❌ Benchmark failed: #{format_error(reason)}")
        System.halt(1)
    end
  end

  defp format_error({:invalid_chunk_id, chunk_id}), do: "Invalid chunk ID: #{chunk_id}"
  defp format_error({:chunk_not_found, chunk_id}), do: "Chunk not found: #{chunk_id}"
  defp format_error({:invalid_keyword, keyword}), do: "Invalid keyword: #{inspect(keyword)}"
  defp format_error({:no_context_found, keyword}), do: "No context found for keyword: #{keyword}"
  defp format_error({:provider_not_found, provider}), do: "Provider not found: #{provider}"
  defp format_error({:model_config_not_found, model}), do: "Model config not found: #{model}"
  defp format_error({:llm_error, reason}), do: "LLM error: #{inspect(reason)}"
  defp format_error({:generation_error, reason}), do: "Generation error: #{inspect(reason)}"
  defp format_error(reason), do: inspect(reason)
end