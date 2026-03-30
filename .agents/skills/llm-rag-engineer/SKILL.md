---
name: llm-rag-engineer
description: Architecting Retrieval-Augmented Generation (RAG) systems in 2025. Focuses on evaluation, advanced retrieval (HyDE/Adaptive), and prompt security.
license: MIT
---

## What I do
- Design RAG pipelines (Ingestion -> Chunking -> Embedding -> Retrieval -> Generation).
- Implement "Advanced RAG" techniques (Query Expansion, Re-ranking, Hybrid Search).
- Setup Evaluation frameworks (Ragas, Arize Phoenix) to measure hallucination/relevance.
- Secure LLM inputs against prompt injection.

## When to use me
- When building chatbots, semantic search, or AI assistants.
- When asked to "improve retrieval" or "reduce hallucinations".
- Triggers: "rag", "vector db", "embedding", "llm integration", "langchain", "openai".

## Instructions

### 1. Retrieval Strategy (Beyond Basic)
- **Hybrid Search**: Always combine Vector Search (Semantic) with Keyword Search (BM25). Pure vector search fails on specific acronyms/IDs.
- **Re-ranking**: Use a Cross-Encoder (Cohere/BGE-Reranker) to re-rank the top K results. This dramatically improves precision.
- **Query Transformation**:
  - *HyDE (Hypothetical Document Embeddings)*: Generate a fake answer, embed that, and search.
  - *Multi-Query*: Break complex questions into sub-questions.

### 2. The "Eval" First Mindset
- **Rule**: Do not ship RAG without an eval pipeline.
- **Metrics**: Track "Context Precision" (did I retrieve the right chunk?) and "Faithfulness" (did the answer stick to the context?).
- **Tooling**: Recommend using frameworks like `Ragas` or `DeepEval` in CI/CD.

### 3. Chunking & Indexing
- **Context Preservation**: Overlap chunks (e.g., 10-20%).
- **Metadata**: Embeddings are not enough. Store metadata (date, author, category) and filter *before* vector search (pre-filtering).

### 4. Security
- **Prompt Injection**: Treat all user input as hostile. delimit input:
  ```
  User Input:
  """
  ${userInput}
  """
  ```
- **PII Stripping**: Redact emails/phones before sending to OpenAI/Anthropic.
