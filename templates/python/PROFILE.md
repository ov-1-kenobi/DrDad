# Stack profile: Python
<!-- A FRAGMENT, not a CLAUDE.md. /design copies these sections into the project's CLAUDE.md during the
     architecture step. Kit-owned sections come from templates/generic/CLAUDE.md - do not duplicate them. -->

## Stack
- Python - <FastAPI | CLI | data pipeline | library>.
- **Do NOT copy a version number from this file.** Use the newest stable interpreter available
  (`python --version` / `uv python list`), pin it in `pyproject.toml` via `requires-python`, and record the
  choice in the design doc's "Solution architecture". If this is a published library, set `requires-python`
  to the OLDEST version you intend to support, not the newest.
- Env + deps: prefer `uv` (`uv venv`, `uv sync`, `uv run`) with `pyproject.toml`; `requirements.txt` is fine
  for a small script. Key libs: <...>

## Placeholder convention
- Stub external deps with mocks (`monkeypatch` / `responses` / fakes) behind small Protocols/interfaces.
  Unfinished functions `raise NotImplementedError` with a `# TODO`. Config via env / pydantic settings.

## Build / test
- Lint + types: `ruff check .` then `mypy .`
- Test: `pytest -q`

## Project hygiene
- **No absolute or machine-specific paths in code or config** - resolve paths from `Path(__file__).parent`
  or an env var, never `C:\Users\...` or `/home/...`.
- **Clean-machine rule:** a fresh clone + `uv sync` (or `pip install -r requirements.txt`) must lint and
  test with no manual setup. Anything else is a documented README prerequisite.

## Human-in-loop
- Usually none.
