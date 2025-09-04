# Question Generation Usage Guide

This guide provides comprehensive instructions for using the Exmeralda question generation system.

## Quick Start

The question generation system is primarily accessed through the CLI:

```bash
# Generate questions from a specific chunk
mix exmeralda.generate_questions --chunk-id <UUID>

# Generate questions from a random chunk  
mix exmeralda.generate_questions --random

# Generate questions from a keyword
mix exmeralda.generate_questions --keyword "changeset"

# Run performance benchmark
mix exmeralda.generate_questions --benchmark
```

## Installation & Setup

### Prerequisites

1. **Elixir/Phoenix Application**: Exmeralda must be properly set up
2. **Database**: PostgreSQL with chunks ingested
3. **LLM Provider**: At least one provider configured (mock, ollama, or external)

### Verify Setup

```bash
# Check available providers and models
mix exmeralda.generate_questions --list-models

# Check chunk statistics
mix exmeralda.generate_questions --stats

# List available chunks
mix exmeralda.generate_questions --list
```

## Usage Patterns

### 1. Development & Testing

**Use Case**: Fast iteration, testing, CI/CD

```bash
# Use mock provider for speed (4ms response)
mix exmeralda.generate_questions --random --provider mock --count 3

# Batch processing for testing
mix exmeralda.generate_questions --chunk-ids "uuid1,uuid2" --provider mock
```

### 2. Production Quality Generation

**Use Case**: High-quality questions for evaluation

```bash
# Use local LLM for quality (1300ms response, 7/10 quality)
mix exmeralda.generate_questions --random --provider ollama_ai --model llama3.2:3b

# Keyword-based generation with context discovery
mix exmeralda.generate_questions --keyword "validation" --provider ollama_ai
```

### 3. Batch Processing

**Use Case**: Generate questions for multiple chunks

```bash
# Process multiple chunks with progress reporting
mix exmeralda.generate_questions --chunk-ids "uuid1,uuid2,uuid3" --show-progress

# Customize batch settings
mix exmeralda.generate_questions --chunk-ids "uuid1,uuid2" --batch-size 5 --max-concurrency 2

# Process random chunks by type
mix exmeralda.generate_questions --random --count 5 --type code --provider ollama_ai
```

## CLI Reference

### Core Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `--chunk-id UUID` | Generate from specific chunk | `--chunk-id a1b2c3d4...` |
| `--chunk-ids "uuid1,uuid2"` | Batch process chunks | `--chunk-ids "uuid1,uuid2,uuid3"` |
| `--keyword WORD` | Generate from keyword | `--keyword "changeset"` |
| `--random` | Use random chunk(s) | `--random --count 3` |

### Configuration Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `--provider NAME` | LLM provider | Auto-detect | `--provider ollama_ai` |
| `--model NAME` | Model config | Auto-detect | `--model llama3.2:3b` |
| `--questions N` | Questions per chunk | 3 | `--questions 5` |
| `--context TEXT` | Custom context for keywords | None | `--context "..."` |

### Filtering Options

| Option | Description | Example |
|--------|-------------|---------|
| `--library NAME` | Filter by library | `--library ecto` |
| `--type TYPE` | Filter by chunk type | `--type code` |
| `--count N` | Number of chunks (with --random) | `--count 5` |

### Batch Processing Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `--batch-size N` | Chunks per batch | 10 | `--batch-size 5` |
| `--max-concurrency N` | Concurrent requests | 3 | `--max-concurrency 2` |
| `--show-progress` | Show progress reports | false | `--show-progress` |

### Utility Commands

| Command | Purpose |
|---------|---------|
| `--list` | List available chunks |
| `--list-models` | Show providers and models |
| `--stats` | Display chunk statistics |
| `--benchmark` | Run performance comparison |
| `--help` | Show detailed help |

## Provider Configuration

### Mock Provider (Development)

**Best for**: Testing, CI/CD, fast iteration

```bash
# Automatic mock usage (no setup required)
mix exmeralda.generate_questions --random --provider mock
```

**Characteristics**:
- ⚡ ~4ms response time
- 🔄 Consistent output (3 generic questions)
- 💰 Free
- 📊 Quality: 5/10

### Ollama Provider (Production)

**Best for**: Production quality, privacy, cost optimization

**Setup**:
```bash
# Install Ollama
brew install ollama

# Start service
ollama serve

# Pull model
ollama pull llama3.2:3b

# Verify availability
mix exmeralda.generate_questions --list-models
```

**Usage**:
```bash
# High-quality question generation
mix exmeralda.generate_questions --random --provider ollama_ai --model llama3.2:3b
```

**Characteristics**:
- 🐌 ~1300ms response time
- 🎯 Content-aware, contextual questions
- 💰 Free after setup (compute costs)
- 📊 Quality: 7/10

### External Providers (API-based)

**Best for**: Highest quality, scalability

**Setup**: Configure API keys in environment

**Usage**:
```bash
# When properly configured
mix exmeralda.generate_questions --random --provider together_ai
```

**Characteristics**:
- ⚡ ~1-3s response time
- 🎯 Highest potential quality
- 💰 Pay per request
- 📊 Quality: Varies by model

## Advanced Usage

### Programmatic Usage

```elixir
# In IEx or application code
alias Exmeralda.Evaluation.QuestionGenerator

# Generate from chunk
{:ok, questions} = QuestionGenerator.from_chunk(chunk_id, 
  model_provider: "ollama_ai", 
  model_config: "llama3.2:3b",
  question_count: 5
)

# Generate from keyword with automatic context
{:ok, questions} = QuestionGenerator.from_keyword("changeset", nil,
  model_provider: "ollama_ai"
)

# Batch processing
{:ok, results} = QuestionGenerator.from_chunks([uuid1, uuid2, uuid3],
  batch_size: 5,
  max_concurrency: 2,
  show_progress: true
)
```

### Custom Benchmarking

```elixir
alias Exmeralda.Evaluation.Benchmark

# Custom benchmark with specific providers
Benchmark.run_comparison(
  chunk_count: 3,
  providers: [
    %{provider: "mock", model: "llm-fake-model"},
    %{provider: "ollama_ai", model: "llama3.2:3b"}
  ],
  output_format: :json
)

# Measure single request latency
{:ok, result} = Benchmark.measure_latency(chunk_id, 
  model_provider: "ollama_ai"
)
# => %{response_time_ms: 1450, questions: [...], question_count: 3}
```

## Troubleshooting

### Common Issues

**"Provider not found: mock"**
```bash
# Check available providers
mix exmeralda.generate_questions --list-models

# Ensure providers are seeded in database
```

**"Model not found: llama3.2:latest"**
```bash
# Check available models in Ollama
ollama list

# Pull required model
ollama pull llama3.2:3b
```

**"Authentication failure with request"**
```bash
# Check API keys for external providers
echo $OPENAI_API_KEY
echo $TOGETHER_API_KEY

# Verify provider configuration
```

**"No chunks available"**
```bash
# Check chunk statistics
mix exmeralda.generate_questions --stats

# Verify data ingestion
mix exmeralda.ingest_library ecto
```

### Performance Issues

**Slow response times with Ollama**:
- Check system resources (CPU/Memory/GPU)
- Use smaller models (llama3.2:1b instead of 32b)
- Reduce concurrency (`--max-concurrency 1`)

**High API costs with external providers**:
- Use local Ollama for development
- Implement usage monitoring
- Use batch processing efficiently

### Quality Issues

**Generic, low-quality questions**:
- Switch from mock to real LLM provider
- Use larger models when available
- Provide custom context for keyword generation

**Questions don't match content**:
- Verify chunk content is meaningful
- Check provider model capabilities
- Consider chunk type (code vs docs) appropriateness

## Integration Examples

### CI/CD Pipeline

```yaml
# .github/workflows/test.yml
- name: Test Question Generation
  run: |
    mix exmeralda.generate_questions --random --provider mock --count 3
    mix exmeralda.generate_questions --benchmark --benchmark-count 2
```

### Evaluation Workflow

```bash
# 1. Generate diverse test questions
mix exmeralda.generate_questions --random --count 10 --provider ollama_ai > questions.txt

# 2. Generate keyword-specific questions
mix exmeralda.generate_questions --keyword "validation" --questions 5 >> questions.txt

# 3. Run quality benchmark
mix exmeralda.generate_questions --benchmark --benchmark-count 5

# 4. Use questions to test retrieval accuracy
# (Custom evaluation script using generated questions)
```

### Development Workflow

```bash
# Fast iteration during development
alias qgen="mix exmeralda.generate_questions"

# Quick tests
qgen --random --provider mock
qgen --keyword "schema" --provider mock

# Quality checks
qgen --random --provider ollama_ai --questions 1
qgen --benchmark --benchmark-count 3
```

## Best Practices

### Provider Selection

- **Development**: Mock provider for speed and consistency
- **Testing**: Mix of mock and real providers for coverage
- **Production**: Ollama or external providers for quality
- **Cost-sensitive**: Prioritize local Ollama over external APIs

### Batch Processing

- Start with small batch sizes (5-10 chunks)
- Monitor resource usage and adjust concurrency
- Use progress reporting for long-running tasks
- Handle errors gracefully (partial failures are normal)

### Quality Optimization

- Use content-aware providers (ollama, external) for final evaluation
- Provide custom context for keyword-based generation
- Validate generated questions with actual retrieval tests
- Consider question variety and technical specificity

### Performance Optimization

- Cache frequent results when possible
- Use appropriate provider for task (mock for testing, ollama for quality)
- Batch related requests to reduce overhead
- Monitor and optimize database queries for large chunk sets

## API Reference

For detailed API documentation, see:
- `Exmeralda.Evaluation.QuestionGenerator` - Core generation functions
- `Exmeralda.Evaluation.Benchmark` - Performance testing utilities
- `Mix.Tasks.Exmeralda.GenerateQuestions` - CLI interface

For implementation details, see:
- `FEATURE_SPEC_QUESTION_GENERATION.md` - Complete technical specification
- `MODEL_PROVIDER_COMPARISON.md` - Provider analysis and recommendations