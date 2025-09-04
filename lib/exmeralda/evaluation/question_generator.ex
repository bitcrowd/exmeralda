defmodule Exmeralda.Evaluation.QuestionGenerator do
  @moduledoc """
  AI-powered question generation for RAG system evaluation.

  This module generates questions from text inputs that can be systematically used 
  to test and improve retrieval function performance in Exmeralda's RAG system.

  ## Usage

      # Generate questions from a specific chunk
      {:ok, questions} = QuestionGenerator.from_chunk(chunk_id)

      # Generate questions from a keyword with optional context
      {:ok, questions} = QuestionGenerator.from_keyword("validation", context)

      # Batch process multiple chunks
      {:ok, results} = QuestionGenerator.from_chunks([chunk_id1, chunk_id2])

  ## Configuration

  The module supports several configuration options:

  - `:question_count` - Number of questions to generate (default: 3)
  - `:model_provider` - Specify LLM provider name (e.g., "ollama_ai", "mock")
  - `:model_config` - Specify model config name (e.g., "llama3.2:latest", "qwen25-coder-32b")
  - `:temperature` - LLM temperature setting (default: 0.7)
  - `:max_tokens` - Maximum response length (default: 500)

  """

  alias Exmeralda.Repo
  alias Exmeralda.Topics.Chunk
  import Ecto.Query
  require Logger

  @default_opts [
    question_count: 3,
    temperature: 0.7,
    max_tokens: 500,
    model_provider: nil,
    model_config: nil
  ]

  @doc """
  Generates questions from a specific chunk that should retrieve that chunk as a top result.

  ## Parameters

  - `chunk_id` - UUID string identifying the target chunk
  - `opts` - Keyword list of options (see module documentation)

  ## Returns

  - `{:ok, [String.t()]}` - List of generated questions
  - `{:error, term()}` - Error tuple with reason

  ## Examples

      iex> {:ok, questions} = QuestionGenerator.from_chunk("550e8400-e29b-41d4-a716-446655440000")
      iex> length(questions)
      3

  """
  @spec from_chunk(chunk_id :: String.t(), opts :: keyword()) :: 
    {:ok, [String.t()]} | {:error, term()}
  def from_chunk(chunk_id, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    with {:ok, chunk} <- fetch_chunk(chunk_id),
         {:ok, questions} <- generate_from_content(chunk.content, chunk, opts) do
      {:ok, questions}
    else
      error -> error
    end
  end

  @doc """
  Generates questions from a keyword that should retrieve chunks containing that keyword.

  ## Parameters

  - `keyword` - Single keyword to generate questions for
  - `context` - Optional context text to improve question quality
  - `opts` - Keyword list of options (see module documentation)

  ## Returns

  - `{:ok, [String.t()]}` - List of generated questions
  - `{:error, term()}` - Error tuple with reason

  ## Examples

      iex> {:ok, questions} = QuestionGenerator.from_keyword("validation")
      iex> is_list(questions)
      true

  """
  @spec from_keyword(keyword :: String.t(), context :: String.t() | nil, opts :: keyword()) :: 
    {:ok, [String.t()]} | {:error, term()}
  def from_keyword(keyword, context \\ nil, opts \\ [])

  def from_keyword(keyword, context, opts) when is_binary(keyword) do
    opts = Keyword.merge(@default_opts, opts)

    try do
      # If no context provided, retrieve related chunks
      effective_context = context || get_keyword_context(keyword, opts)
      
      case effective_context do
        "" -> {:error, {:no_context_found, keyword}}
        nil -> {:error, {:no_context_found, keyword}}
        context_text ->
          prompt = build_keyword_question_prompt(keyword, context_text, opts)
          
          case call_llm(prompt, opts) do
            {:ok, response} ->
              questions = parse_questions(response)
              {:ok, questions}
            
            {:error, reason} ->
              Logger.error("LLM call failed for keyword '#{keyword}': #{inspect(reason)}")
              {:error, {:llm_error, reason}}
          end
      end
    rescue
      error -> 
        Logger.error("Error generating questions for keyword '#{keyword}': #{inspect(error)}")
        {:error, {:generation_error, error}}
    end
  end

  def from_keyword(keyword, _context, _opts) do
    {:error, {:invalid_keyword, keyword}}
  end

  @doc """
  Batch processes multiple chunks to generate questions for each.

  ## Parameters

  - `chunk_ids` - List of chunk UUID strings
  - `opts` - Keyword list of options (see module documentation)

  ## Returns

  - `{:ok, %{String.t() => [String.t()]}}` - Map of chunk_id to generated questions
  - `{:error, term()}` - Error tuple with reason

  ## Examples

      iex> chunk_ids = ["550e8400-e29b-41d4-a716-446655440000", "550e8400-e29b-41d4-a716-446655440001"]
      iex> {:ok, results} = QuestionGenerator.from_chunks(chunk_ids)
      iex> map_size(results)
      2

  """
  @spec from_chunks([String.t()], keyword()) :: 
    {:ok, %{String.t() => [String.t()]}} | {:error, term()}
  def from_chunks(chunk_ids, opts \\ [])
  def from_chunks(chunk_ids, opts) when is_list(chunk_ids) do
    opts = Keyword.merge(@default_opts, opts)
    
    # Configuration for batch processing
    batch_size = Keyword.get(opts, :batch_size, 10)
    max_concurrency = Keyword.get(opts, :max_concurrency, 3)
    show_progress = Keyword.get(opts, :show_progress, false)
    
    try do
      total_chunks = length(chunk_ids)
      
      if show_progress do
        Logger.info("Starting batch processing of #{total_chunks} chunks (batch_size: #{batch_size}, concurrency: #{max_concurrency})")
      end
      
      # Process in batches to avoid overwhelming the LLM provider
      results = 
        chunk_ids
        |> Enum.chunk_every(batch_size)
        |> Enum.with_index(1)
        |> Enum.reduce_while({:ok, %{}}, fn {batch, batch_num}, {:ok, acc} ->
          if show_progress do
            batch_start = (batch_num - 1) * batch_size + 1
            batch_end = min(batch_num * batch_size, total_chunks)
            Logger.info("Processing batch #{batch_num} (chunks #{batch_start}-#{batch_end})")
          end
          
          case process_batch(batch, opts, max_concurrency) do
            {:ok, batch_results} ->
              {:cont, {:ok, Map.merge(acc, batch_results)}}
            {:error, reason} ->
              {:halt, {:error, {:batch_processing_error, batch_num, reason}}}
          end
        end)
      
      case results do
        {:ok, final_results} ->
          if show_progress do
            successful = final_results |> Map.values() |> Enum.count(&is_list/1)
            Logger.info("Batch processing completed: #{successful}/#{total_chunks} chunks successful")
          end
          {:ok, final_results}
        error -> error
      end
      
    rescue
      error -> 
        Logger.error("Error in batch processing: #{inspect(error)}")
        {:error, {:batch_error, error}}
    end
  end
  
  def from_chunks(chunk_ids, _opts) when not is_list(chunk_ids) do
    {:error, {:invalid_chunk_ids, "chunk_ids must be a list"}}
  end

  # Private helper function to process a batch of chunks with concurrency control
  defp process_batch(chunk_ids, opts, max_concurrency) do
    try do
      # Use Task.async_stream for controlled concurrency
      results = 
        Task.async_stream(
          chunk_ids,
          fn chunk_id ->
            case from_chunk(chunk_id, opts) do
              {:ok, questions} -> {chunk_id, {:ok, questions}}
              {:error, reason} -> {chunk_id, {:error, reason}}
            end
          end,
          max_concurrency: max_concurrency,
          timeout: 30_000, # 30 seconds per chunk
          on_timeout: :kill_task
        )
        |> Enum.reduce_while({:ok, %{}}, fn
          {:ok, {chunk_id, {:ok, questions}}}, {:ok, acc} ->
            {:cont, {:ok, Map.put(acc, chunk_id, questions)}}
          
          {:ok, {chunk_id, {:error, reason}}}, {:ok, acc} ->
            Logger.warning("Failed to generate questions for chunk #{chunk_id}: #{inspect(reason)}")
            {:cont, {:ok, Map.put(acc, chunk_id, {:error, reason})}}
          
          {:exit, {chunk_id, reason}}, {:ok, acc} ->
            Logger.error("Task timeout for chunk #{chunk_id}: #{inspect(reason)}")
            {:cont, {:ok, Map.put(acc, chunk_id, {:error, {:timeout, reason}})}}
            
          error, _acc ->
            {:halt, {:error, {:async_stream_error, error}}}
        end)
      
      results
    rescue
      error ->
        Logger.error("Error in process_batch: #{inspect(error)}")
        {:error, {:process_batch_error, error}}
    end
  end

  @doc """
  Fetches a random chunk from the database for testing purposes.

  ## Returns

  - `{:ok, Chunk.t()}` - A random chunk
  - `{:error, :no_chunks_available}` - If no chunks exist in database

  """
  @spec get_random_chunk() :: {:ok, Chunk.t()} | {:error, :no_chunks_available}
  def get_random_chunk do
    case Repo.all(from c in Chunk, order_by: fragment("RANDOM()"), limit: 1) do
      [chunk] -> {:ok, chunk}
      [] -> {:error, :no_chunks_available}
    end
  end

  @doc """
  Lists chunks with optional filtering by library or type.

  ## Parameters

  - `opts` - Keyword list with optional `:library`, `:type`, `:limit` filters

  ## Examples

      iex> QuestionGenerator.list_chunks(library: "ecto", type: :docs, limit: 5)
      {:ok, [%Chunk{}, ...]}

  """
  @spec list_chunks(keyword()) :: {:ok, [Chunk.t()]} | {:error, term()}
  def list_chunks(opts \\ []) do
    query = from(c in Chunk)

    query = 
      query
      |> maybe_filter_by_library(opts[:library])
      |> maybe_filter_by_type(opts[:type])
      |> maybe_limit(opts[:limit] || 20)
      |> preload([ingestion: :library])

    {:ok, Repo.all(query)}
  rescue
    error -> 
      Logger.error("Error listing chunks: #{inspect(error)}")
      {:error, {:database_error, error}}
  end

  @doc """
  Gets basic statistics about chunks in the database.

  ## Returns

  A map with chunk counts by type, library, etc.
  """
  @spec chunk_stats() :: map()
  def chunk_stats do
    total_count = Repo.aggregate(Chunk, :count)
    
    type_counts = 
      from(c in Chunk, group_by: c.type, select: {c.type, count()})
      |> Repo.all()
      |> Enum.into(%{})

    %{
      total_count: total_count,
      type_counts: type_counts,
      has_chunks: total_count > 0
    }
  rescue
    error -> 
      Logger.error("Error getting chunk stats: #{inspect(error)}")
      %{error: error, total_count: 0, has_chunks: false}
  end

  # Private functions

  defp fetch_chunk(chunk_id) when is_binary(chunk_id) do
    try do
      case Ecto.UUID.cast(chunk_id) do
        {:ok, _uuid} ->
          case Repo.get(Chunk, chunk_id) |> Repo.preload([ingestion: :library]) do
            %Chunk{} = chunk -> {:ok, chunk}
            nil -> {:error, {:chunk_not_found, chunk_id}}
          end
        :error ->
          {:error, {:invalid_chunk_id, chunk_id}}
      end
    rescue
      error -> 
        Logger.error("Error fetching chunk #{chunk_id}: #{inspect(error)}")
        {:error, {:database_error, error}}
    end
  end

  defp fetch_chunk(chunk_id), do: {:error, {:invalid_chunk_id, chunk_id}}

  defp maybe_filter_by_library(query, nil), do: query
  defp maybe_filter_by_library(query, library) do
    from c in query,
      join: i in assoc(c, :ingestion),
      join: l in assoc(i, :library),
      where: l.name == ^library
  end

  defp maybe_filter_by_type(query, nil), do: query
  defp maybe_filter_by_type(query, type), do: from(c in query, where: c.type == ^type)

  defp maybe_limit(query, limit), do: from(c in query, limit: ^limit)

  defp generate_from_content(content, chunk, opts) do
    try do
      prompt = build_question_prompt(content, chunk, opts)
      
      case call_llm(prompt, opts) do
        {:ok, response} ->
          questions = parse_questions(response)
          {:ok, questions}
        
        {:error, reason} ->
          Logger.error("LLM call failed: #{inspect(reason)}")
          {:error, {:llm_error, reason}}
      end
    rescue
      error -> 
        Logger.error("Error generating questions: #{inspect(error)}")
        {:error, {:generation_error, error}}
    end
  end

  # Builds a prompt for question generation from chunk content
  defp build_question_prompt(content, chunk, opts) do
    question_count = Keyword.get(opts, :question_count, 3)
    
    """
    You are an expert at generating evaluation questions from technical documentation and code.

    Your task is to generate #{question_count} high-quality questions that can be answered using the provided content. The questions should:
    1. Be specific and answerable using the given content
    2. Cover different aspects of the material (concepts, usage, examples)
    3. Be naturally phrased as if asked by a developer
    4. Vary in complexity from basic to intermediate

    Content Type: #{chunk.type}
    Source: #{chunk.source}
    Library: #{get_library_name(chunk)}

    Content:
    #{content}

    Generate exactly #{question_count} questions. Return them as a simple numbered list without any additional formatting or explanation:

    1. [First question]
    2. [Second question]
    #{if question_count > 2, do: "3. [Third question]", else: ""}
    #{if question_count > 3, do: "...", else: ""}
    """
  end

  # Gets library name from chunk, handling the association
  defp get_library_name(chunk) do
    case chunk do
      %{ingestion: %{library: %{name: name}}} -> name
      %{library: %{name: name}} -> name
      _ -> "Unknown"
    end
  end

  # Calls the LLM with a simple approach using available providers
  defp call_llm(prompt, opts) do
    case get_default_llm_config(opts) do
      {:ok, llm_config} ->
        # Check if this is our mock LLM
        if is_mock_llm?(llm_config) do
          # Handle mock LLM directly
          {:ok, llm_config.response}
        else
          # Create a simple synchronous LLM call for real providers
          chain = 
            %{llm: llm_config}
            |> LangChain.Chains.LLMChain.new!()
            |> LangChain.Chains.LLMChain.add_messages([
              LangChain.Message.new_user!(prompt)
            ])
          
          case LangChain.Chains.LLMChain.run(chain) do
            {:ok, %{messages: messages}} ->
              case List.last(messages) do
                %{content: content} -> {:ok, content}
                _ -> {:error, :no_response_content}
              end
            {:error, reason} -> {:error, reason}
            error -> {:error, error}
          end
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper to check if LLM config is our mock
  defp is_mock_llm?(%{__struct__: :mock}), do: true
  defp is_mock_llm?(_), do: false

  # Get a default LLM configuration (preferring non-mock providers)
  defp get_default_llm_config(opts \\ []) do
    case find_usable_provider(opts) do
      {:ok, provider_config} ->
        {:ok, create_llm_instance(provider_config)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Find a usable provider with configurable selection
  defp find_usable_provider(opts \\ []) do
    providers = Repo.all(Exmeralda.LLM.Provider)
    model_configs = Repo.all(Exmeralda.LLM.ModelConfig)
    
    case {providers, model_configs} do
      {[], _} -> {:error, :no_providers_available}
      {_, []} -> {:error, :no_model_configs_available}
      {providers, model_configs} ->
        provider = select_provider(providers, opts[:model_provider])
        model_config = select_model_config(model_configs, opts[:model_config])
        
        case {provider, model_config} do
          {nil, _} -> {:error, {:provider_not_found, opts[:model_provider]}}
          {_, nil} -> {:error, {:model_config_not_found, opts[:model_config]}}
          {provider, model_config} -> {:ok, %{provider: provider, model_config: model_config}}
        end
    end
  end

  # Select provider based on options or default logic
  defp select_provider(providers, nil) do
    # Default: prefer non-mock providers for real evaluation
    non_mock_provider = Enum.find(providers, &(&1.type != :mock))
    non_mock_provider || hd(providers)
  end
  
  defp select_provider(providers, provider_name) when is_binary(provider_name) do
    Enum.find(providers, &(&1.name == provider_name))
  end

  # Select model config based on options or default logic
  defp select_model_config(model_configs, nil) do
    # Default: prefer non-fake models
    suitable_model = Enum.find(model_configs, fn config ->
      !String.contains?(String.downcase(config.name), "fake")
    end)
    suitable_model || hd(model_configs)
  end
  
  defp select_model_config(model_configs, model_name) when is_binary(model_name) do
    Enum.find(model_configs, &(&1.name == model_name))
  end

  # Create an LLM instance from provider configuration
  defp create_llm_instance(%{provider: provider, model_config: model_config}) do
    params =
      %{"model" => model_config.name}
      |> Map.merge(model_config.config)
      |> Map.merge(provider.config)
      |> maybe_add_api_key(provider)

    case provider.type do
      :mock -> 
        # Use a more realistic mock response for testing
        %{__struct__: :mock, response: "1. How do you use #{model_config.name} in Elixir applications?\n2. What are the main features of this library?\n3. How do you handle errors when working with this code?"}
      :ollama -> 
        LangChain.ChatModels.ChatOllamaAI.new!(params)
      :openai -> 
        LangChain.ChatModels.ChatOpenAI.new!(params)
    end
  end

  # Add API key if needed (copied from existing LLM module)
  defp maybe_add_api_key(params, %{name: name, type: :openai}) do
    case Application.fetch_env(:exmeralda, :llm_api_keys) do
      {:ok, api_keys} -> Map.put(params, "api_key", Map.get(api_keys, name))
      :error -> params  # No API keys configured
    end
  end
  
  defp maybe_add_api_key(params, _provider), do: params

  # Parse questions from LLM response
  defp parse_questions(response) when is_binary(response) do
    response
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(fn line -> 
      String.match?(line, ~r/^\d+\./) # Lines starting with number and dot
    end)
    |> Enum.map(fn line ->
      line
      |> String.replace(~r/^\d+\.\s*/, "") # Remove number prefix
      |> String.trim()
    end)
    |> Enum.reject(&(&1 == "")) # Remove empty strings
  end

  # Handle mock LLM response
  defp parse_questions(%{__struct__: :mock, response: response}), do: parse_questions(response)

  # Get context for keyword-based question generation
  defp get_keyword_context(keyword, opts) do
    search_limit = Keyword.get(opts, :context_chunks, 5)
    
    # Search for chunks containing the keyword
    case search_chunks_by_keyword(keyword, search_limit) do
      {:ok, []} -> 
        Logger.info("No chunks found for keyword '#{keyword}'")
        nil
        
      {:ok, chunks} ->
        # Combine content from multiple chunks as context
        context_parts = Enum.map(chunks, fn chunk ->
          content_preview = String.slice(chunk.content, 0, 500)
          "## From #{chunk.source} (#{chunk.type}):\n#{content_preview}..."
        end)
        
        Enum.join(context_parts, "\n\n")
        
      {:error, reason} ->
        Logger.error("Error searching for keyword '#{keyword}': #{inspect(reason)}")
        nil
    end
  end

  # Search for chunks containing the keyword
  defp search_chunks_by_keyword(keyword, limit) do
    query = 
      from c in Chunk,
      where: ilike(c.content, ^"%#{keyword}%"),
      limit: ^limit,
      preload: [ingestion: :library]
    
    chunks = Repo.all(query)
    {:ok, chunks}
  rescue
    error -> 
      {:error, error}
  end

  # Build prompt for keyword-based question generation
  defp build_keyword_question_prompt(keyword, context, opts) do
    question_count = Keyword.get(opts, :question_count, 3)
    
    """
    You are an expert at generating evaluation questions from technical documentation and code.

    Your task is to generate #{question_count} high-quality questions that focus on the keyword "#{keyword}" using the provided context. The questions should:
    1. Specifically relate to the concept or functionality of "#{keyword}"
    2. Be answerable using information from the context provided
    3. Cover different aspects of #{keyword} (usage, implementation, best practices)
    4. Be naturally phrased as if asked by a developer learning about #{keyword}
    5. Vary in complexity from basic to intermediate

    Keyword Focus: #{keyword}

    Context Information:
    #{context}

    Generate exactly #{question_count} questions that would help evaluate understanding of "#{keyword}". 
    Return them as a simple numbered list without any additional formatting or explanation:

    1. [First question about #{keyword}]
    2. [Second question about #{keyword}]
    #{if question_count > 2, do: "3. [Third question about #{keyword}]", else: ""}
    #{if question_count > 3, do: "...", else: ""}
    """
  end
end