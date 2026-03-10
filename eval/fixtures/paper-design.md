# Design
> paper-manager v0.3.0

## Tech Stack

- **Python 3.11**: Backend (FastAPI, SQLAlchemy, PyMuPDF, BeautifulSoup4)
- **TypeScript/React**: Frontend SPA
- **SQLite**: Primary storage (papers, authors, collections)
- **Whoosh**: Full-text search index
- **sentence-transformers**: Vector embeddings for semantic search

## Architecture

- Monolith with 4 layers: parser → indexer → api → ui
- Parser: stateless pipeline, each format (PDF/HTML/BibTeX) is a separate handler
- Indexer: dual-mode search (keyword via Whoosh + semantic via embeddings), hybrid ranking
- API: FastAPI with async endpoints, Pydantic validation
- UI: React SPA consuming REST API

## Patterns

- Pipeline pattern: ingestion stages are composable (extract → transform → load)
- Repository pattern: `src/models/repo.py` abstracts SQLAlchemy queries
- Hybrid search: weighted combination of BM25 (Whoosh) and cosine similarity (embeddings)
- Bulk import: background task via FastAPI BackgroundTasks

## Key Decisions

- SQLite over PostgreSQL: single-user desktop app, no concurrent write pressure
- Whoosh over Elasticsearch: lightweight, no external service dependency
- Hybrid search: BM25 alone misses semantic matches, embeddings alone miss exact phrases
- PyMuPDF over pdfplumber: faster extraction, better table handling
