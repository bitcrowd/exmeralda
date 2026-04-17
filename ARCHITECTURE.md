# Exmeralda Architecture Overview

Exmeralda is a RAG-powered assistant that helps developers explore and understand Elixir libraries published on Hex.pm. Users can select a library, and the system ingests its documentation and source code to provide contextually relevant answers to questions.

### Tech Stack

| Component | Technology |
|-----------|------------|
| Backend | Elixir, Phoenix Framework |
| Frontend | Phoenix LiveView |
| Database | PostgreSQL 17 with pgvector extension |
| Background Jobs | Oban |
| LLM Integration | LangChain (Elixir) |
| RAG Framework | [rag](https://hex.pm/packages/rag) (Elixir library by bitcrowd) |
| Embeddings | OpenAI-compatible APIs, Ollama (dev) |
| LLM Providers | Ollama (dev), Together AI, Lambda AI, Hyperbolic AI, Groq AI (prod) |

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           User Interface                                 │
│                     (Phoenix LiveView Chat)                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            Exmeralda.Chats                               │
│              (Session Management, Message Handling)                      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
┌───────────────────────────────┐   ┌───────────────────────────────────┐
│     RETRIEVAL                 │   │         GENERATION                │
│  Exmeralda.Topics.Rag         │   │     Exmeralda.Chats.LLM           │
│  - Hybrid Search              │   │     - LangChain Integration       │
│  - pgvector + Full-text       │   │     - Streaming Responses         │
│  - RRF Fusion                 │   │     - Multi-provider Support      │
└───────────────────────────────┘   └───────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         INGESTION PIPELINE                               │
│                    (Oban Background Workers)                             │
│  IngestLibraryWorker → EnqueueGenerateEmbeddingsWorker →                │
│                        GenerateEmbeddingsWorker                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           Data Sources                                   │
│              Hex.pm (docs tarball + source tarball)                      │
└─────────────────────────────────────────────────────────────────────────┘
```

## 2. Core Concepts & Data Model

### Entity Relationship Overview

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Library    │────<│  Ingestion   │────<│    Chunk     │
│  (name,ver)  │     │   (state)    │     │ (type,embed) │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            │
                     ┌──────┴──────┐
                     ▼             │
              ┌──────────────┐     │
              │   Session    │─────┘
              │   (title)    │
              └──────────────┘
                     │
                     ▼
              ┌──────────────┐     ┌──────────────┐
              │   Message    │────<│    Source    │───> Chunk
              │ (role,content)     │  (chunk_id)  │
              └──────────────┘     └──────────────┘
                     │
                     ▼
              ┌──────────────────────┐
              │ GenerationEnvironment │
              │ (model, prompts)      │
              └──────────────────────┘
```
## 3. Ingestion Pipeline

The ingestion pipeline processes a Hex library into searchable chunks with embeddings.

### Pipeline Overview

```
create_library/2
       │
       ▼
┌──────────────────────────┐
│  IngestLibraryWorker     │  Oban queue: :ingest
│  - Fetch docs from Hex   │
│  - Fetch tarball from Hex│
│  - Chunk text content    │
│  - Insert chunks to DB   │
└──────────────────────────┘
       │
       ▼
┌──────────────────────────┐
│ EnqueueGenerateEmbeddings│  Oban queue: :ingest
│ Worker                   │
│ - Query all chunk IDs    │
│ - Batch into groups of 20│
│ - Enqueue worker per batch│
└──────────────────────────┘
       │
       ▼ (multiple parallel jobs)
┌──────────────────────────┐
│ GenerateEmbeddingsWorker │  Oban queue: :ingest
│ - Load chunks by IDs     │
│ - Call embedding API     │
│ - Update chunk.embedding │
│ - Mark ingestion ready   │
│   when all done          │
└──────────────────────────┘
