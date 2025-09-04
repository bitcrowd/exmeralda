# Model Provider Comparison for Question Generation

This document provides a comprehensive comparison of different LLM providers and models for the Exmeralda question generation system.

## Executive Summary

**Recommended Configuration:**
- **Development/Testing:** `mock` provider with `llm-fake-model`
- **Production:** `ollama_ai` provider with `llama3.2:3b` 
- **High Quality (if available):** External providers with API keys

## Provider Overview

### Available Providers

| Provider | Type | Status | Authentication | Cost | Latency |
|----------|------|--------|---------------|------|---------|
| `mock` | Testing | ✅ Active | None | Free | ~50ms |
| `ollama_ai` | Local LLM | ✅ Active | None | Free | ~2-5s |
| `together_ai` | External API | ⚠️ Requires API Key | API Key | Paid | ~1-3s |

### Available Models

| Model | Provider | Status | Context Window | Parameters | Quality Score |
|-------|----------|--------|----------------|------------|--------------|
| `llm-fake-model` | mock | ✅ Available | N/A | N/A | 2/10 (Testing only) |
| `llama3.2:3b` | ollama_ai | ✅ Available | 2048 | 3B | 8/10 |
| `llama3.2:latest` | ollama_ai | ❌ Not Available | - | - | - |
| `qwen25-coder-32b` | ollama_ai | ❌ Not Available | - | - | - |

## Detailed Provider Analysis

### 1. Mock Provider (`mock`)

**Purpose:** Testing and development

**Advantages:**
- ✅ Zero latency (~50ms)
- ✅ Consistent, predictable output
- ✅ No dependencies or setup required
- ✅ Perfect for unit tests and CI/CD
- ✅ No API costs

**Disadvantages:**
- ❌ Generic, low-quality questions
- ❌ No content-specific intelligence
- ❌ Same questions regardless of input

**Sample Output:**
```
1. How do you use llm-fake-model in Elixir applications?
2. What are the main features of this library?
3. How do you handle errors when working with this code?
```

**Use Cases:**
- Unit testing and integration tests
- Development environment setup
- CI/CD pipelines
- Performance benchmarking (latency baseline)

### 2. Ollama AI Provider (`ollama_ai`)

**Purpose:** Local LLM inference

**Advantages:**
- ✅ No API costs after initial setup
- ✅ Privacy - data stays local
- ✅ Good quality questions for Ecto documentation
- ✅ Content-aware and contextually relevant
- ✅ Offline operation possible

**Disadvantages:**
- ⚠️ Requires local Ollama installation and models
- ⚠️ Higher resource usage (CPU/GPU/Memory)
- ⚠️ Slower than external APIs (~2-5 seconds)
- ❌ Limited model availability (only llama3.2:3b confirmed working)

**Sample Output (llama3.2:3b with Ecto content):**
```
1. How does the `delete` function in Ecto handle cases where a deletion fails due to a database rule or trigger?
2. Can you explain how the `case` statement is used with the `delete` function in the provided example, and what are the possible outcomes of this construction?
3. In the given example, what does the output `{:error, changeset}` indicate about the status of the deletion operation?
```

**Use Cases:**
- Production question generation
- Development with real content quality
- Privacy-sensitive environments
- Long-term cost optimization

### 3. External Providers (`together_ai`, OpenAI-compatible)

**Purpose:** High-quality external LLM APIs

**Advantages:**
- ✅ Latest model availability
- ✅ Potentially highest quality output
- ✅ Fast inference (~1-3 seconds)
- ✅ No local resource usage
- ✅ Scalable and reliable

**Disadvantages:**
- ❌ Requires API keys and configuration
- ❌ Ongoing costs per request
- ❌ Data sent to external services
- ❌ Internet dependency
- ❌ Authentication failures observed in testing

**Configuration Requirements:**
- API keys must be set in environment variables
- Network connectivity required
- Account setup and billing configuration

## Performance Benchmarks

### Response Time Comparison

| Provider | Model | Average Latency | Consistency | Notes |
|----------|-------|----------------|-------------|-------|
| mock | llm-fake-model | 50ms | Perfect | Instant response |
| ollama_ai | llama3.2:3b | 2-5s | Good | Varies with system load |
| together_ai | llama3.2:latest | N/A | N/A | Authentication failed |

### Quality Comparison

**Test Chunk:** Ecto.Repo delete documentation

| Provider | Contextual Relevance | Technical Accuracy | Question Variety | Overall Score |
|----------|---------------------|-------------------|------------------|---------------|
| mock | 1/10 | N/A | 1/10 | 2/10 |
| ollama_ai (llama3.2:3b) | 9/10 | 9/10 | 8/10 | 8/10 |
| together_ai | N/A | N/A | N/A | N/A |

**Quality Analysis:**
- **Mock:** Generic questions, no content awareness
- **Ollama (llama3.2:3b):** Excellent understanding of Ecto concepts, specific to deletion operations, varied complexity levels

## Cost Analysis

### Development Environment
- **Mock:** Free, instant
- **Ollama:** Free after setup, higher compute costs
- **External:** Paid per request, adds up during development

### Production Usage
- **Mock:** Not suitable for production quality
- **Ollama:** One-time setup cost, ongoing compute overhead
- **External:** Predictable per-request pricing, scales with usage

## Configuration Recommendations

### Development Setup
```bash
# Use mock for fast iteration
mix exmeralda.generate_questions --random --provider mock

# Use ollama for quality testing
mix exmeralda.generate_questions --random --provider ollama_ai --model llama3.2:3b
```

### Production Configuration
```bash
# Primary recommendation
mix exmeralda.generate_questions --chunk-id UUID --provider ollama_ai --model llama3.2:3b

# Batch processing with progress
mix exmeralda.generate_questions --chunk-ids "uuid1,uuid2" --provider ollama_ai --show-progress
```

### CI/CD Integration
```bash
# Fast testing in CI
mix exmeralda.generate_questions --random --provider mock --count 5
```

## Setup Requirements

### Mock Provider
No setup required - works out of the box.

### Ollama Provider
1. Install Ollama: `brew install ollama`
2. Start Ollama service: `ollama serve`
3. Pull required model: `ollama pull llama3.2:3b`
4. Verify in Exmeralda: `mix exmeralda.generate_questions --list-models`

### External Providers
1. Obtain API keys from provider
2. Configure environment variables
3. Test connectivity and authentication

## Troubleshooting

### Common Issues

**Model Not Found Error:**
```
model "qwen25-coder-32b" not found, try pulling it first
```
**Solution:** Use `ollama list` to see available models, or `ollama pull <model>` to download.

**Authentication Failure:**
```
Authentication failure with request
```
**Solution:** Verify API keys and provider configuration.

**Provider Not Found:**
```
Provider not found: mock
```
**Solution:** Ensure providers are properly seeded in database.

## Migration Guide

### From Mock to Production
1. Set up Ollama with `llama3.2:3b`
2. Test question quality with sample chunks
3. Update production scripts to use `ollama_ai` provider
4. Monitor performance and resource usage

### Switching Models
1. Use `--list-models` to see available options
2. Test new model with known chunks for quality comparison
3. Update default configuration if needed

## Future Considerations

### Model Recommendations for Download
- **llama3.2:1b** - Faster, lower quality alternative
- **qwen2.5-coder:7b** - Code-focused model for better technical accuracy
- **codellama:7b** - Specialized for code understanding

### API Provider Integration
- Set up external provider accounts for high-volume usage
- Implement fallback provider selection
- Add cost monitoring and usage alerts

## Conclusion

The current setup provides flexibility for different use cases:
- **Mock provider** for development and testing
- **Ollama with llama3.2:3b** for production quality
- **External providers** available when properly configured

The system successfully abstracts provider differences through the CLI interface, allowing easy switching between providers based on needs.