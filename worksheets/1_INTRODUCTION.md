# Worksheet 1 — Introduction to RAG

**Duration:** ~60 minutes

---

## Agenda

1. **Setup** (5–10 min)
   - Clone, `scripts/start`, `localhost:4000`
   - Verify: pre-seeded library appears, `/admin` loads, `/oban` loads
2. **First contact: chat** (10 min)
   - Use the shared prompt bank (4 questions across the categories)
   - Record one-line impression per answer + a failure-mode tag
3. **Open the hood: architecture & data model** (15 min)
   - Read `ARCHITECTURE.md`, look at `docs/model.png`
   - Inspect: Chunks from the database, use `scripts/psql`, fetch one `:docs` chunk and one `:code` chunk.
4. **Trace one question end-to-end** (15 min)
   - IEx: `Rag.build_generation/2` for one of your prompt-bank questions
   - Inspect: which chunks came back? from docs or code? does the final prompt actually contain the info needed to answer?
5. **Tweak the generation environment** (15 min)
   - Via `/admin`: create a new SystemPrompt, activate it, re-ask the same 4 questions
   - Did the answers get better?

---

## 1. Setup

## 2. First contact: Chat

## 3. Architecture & data model

## 4. Trace one question end-to-end

## 5. Tweak the generation environment

---

## Appendix A — Shared prompt bank (for the seeded `jason` library)

| # | Category | Prompt |
|---|----------|--------|
| 1 | Answerable from docs | *How do I encode a map to JSON with Jason?* |
| 2 | Answerable from code | *What does the `Jason.Encoder` protocol require me to implement for a custom struct?* |
| 3 | Ambiguous / partial | *How does Jason handle atoms as map keys?* |
| 4 | Out-of-scope / unanswerable from jason alone | *How does Jason compare to Poison in benchmarks?* |
