# Worksheet 3 — Synthetic dataset creation & evaluation

**Duration:** ~60 minutes

---

## Agenda

1. **Generate synthetic questions** (10 min)
   - `Evaluation.question_generation/2`
      - One question for one chunk, inspect the prompt and the output.
   - `Evaluation.batch_question_generation/3` with `limit: 10, download: true`
      - Inspect the result JSON.
2. **Evaluate** (10 min)
   - `Evaluation.batch_evaluation(path, aggregate: true)`
      - Inspect results read first_hit, rank, `chunk_was_found?`.
3. **Compare rankers** (10 min)
   - `batch_evaluation(..., results: [:rrf_result, :semantic_results, :fulltext_results])`
   - Which retrieval strategy is better? Why? Does the question affects the evaluation?
4. **Extend It** (30 min)
   Chage the code, re-run the evaluation and compare:
   - Tune a retrieval cutoff (`@pgvector_limit`, `@fulltext_limit`, or `@retrieval_weights`) and measure the impact
