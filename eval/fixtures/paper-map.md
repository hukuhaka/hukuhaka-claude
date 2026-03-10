# Project Map
> paper-manager v0.3.0

## Entry Points

- [main.py](src/main.py): FastAPI application entry point
- [parser/ingest.py](src/parser/ingest.py): PDF/HTML paper ingestion pipeline
- [parser/extract.py](src/parser/extract.py): Metadata extraction (title, authors, abstract)
- [indexer/search.py](src/indexer/search.py): Full-text search with Whoosh
- [indexer/embeddings.py](src/indexer/embeddings.py): Vector embeddings for semantic search
- [api/routes.py](src/api/routes.py): REST API endpoints (CRUD + search)
- [api/schemas.py](src/api/schemas.py): Pydantic request/response models
- [ui/app.tsx](src/ui/app.tsx): React SPA entry point
- [ui/pages/search.tsx](src/ui/pages/search.tsx): Search page with filters

## Data Flow

Upload (PDF/URL) → parser/ingest.py (extract text) → parser/extract.py (metadata) → indexer/embeddings.py (vectorize) → SQLite storage → api/routes.py (serve) → ui (display)

## Components

- `src/parser/`: Ingestion pipeline — PDF parsing (PyMuPDF), HTML scraping (BeautifulSoup), metadata extraction
- `src/indexer/`: Search infrastructure — Whoosh full-text, sentence-transformers embeddings, hybrid ranking
- `src/api/`: FastAPI REST layer — paper CRUD, search, bulk import
- `src/ui/`: React frontend — search, paper detail, collection management
- `src/models/`: SQLAlchemy models — Paper, Author, Collection, Tag
- `tests/`: pytest suite — unit (parser, indexer) + integration (API endpoints)
