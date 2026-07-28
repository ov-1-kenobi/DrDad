# Project: <name>

## Stack
- Python 3.11 - <FastAPI | CLI | data pipeline | library>.
- Env: venv + `requirements.txt` / `pyproject.toml`. Key libs: <...>

## Modes (forge / proto / spec)  <- read this
If I haven't said which, ASK first.
- `/forge` - design-first: architect & validate the spec INTO the design doc (DRAFT), no code.
- `/proto` - co-design: build greybox + record dated decisions into the design doc (DRAFT).
- `/spec` - implement the design doc faithfully; it is LOCKED & read-only; gaps -> questions.
- `/build [scope]` - orchestrate requirements-agent -> dev-agent -> qa-agent; mode follows the doc Status.
The design doc's `Status:` header is the source of truth: never edit LOCKED; never `/spec` a DRAFT.
Pipeline: forge or proto (DRAFT) -> set LOCKED -> spec/build (implement).

## Design doc
- Design doc: `docs/DESIGN.md` (indexed in `local-tools`; use `search_datasheets` / `doc-researcher`, cite it).

## Placeholder convention
- Stub external deps with mocks (`monkeypatch` / `responses` / fakes) behind small protocols/interfaces.
  Unfinished functions `raise NotImplementedError`  with a `# TODO`. Config via env / pydantic settings.

## Build / test
- Lint + types: `ruff check . ; mypy .`
- Test: `pytest -q`

## Human-in-loop
- Usually none.

## Web / grounding
- Web search / URL lookup: use the `local-tools` `web_search` / `ingest_url` tools, NOT the built-in
  WebSearch/WebFetch (those need Anthropic and don't work against local Ollama). For grounding,
  `web_search` to find, then `ingest_url` to fetch + persist into the RAG.

## Working agreement
- Confirm values against the design doc; cite it. Never invent - missing info is a question.
- After each change: lint + test. Don't say "done" until they pass. Keep changes small and scoped.
