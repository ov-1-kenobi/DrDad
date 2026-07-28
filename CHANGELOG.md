# Changelog

All notable changes to AD-kit. Versions follow semver; the requirement ids (R1-R21) are in `docs/DESIGN.md`.

## 0.9.0 - 2026-07-12

First versioned release. Feature-complete and self-tested; held below 1.0 until a full
`/forge -> /blueprint -> /build` run on real hardware is verified end to end.

### Core (R1-R10)
- Claude Code driven by local Ollama models, fully offline after setup (`settings.json` env redirect,
  no Anthropic account).
- One C# MCP server (`local-tools`): document RAG over per-project corpora with markdown-aware,
  heading-based chunking, atomic index writes, and an opt-in staleness refresh.
- Mode commands, a global agent team, one-command install/uninstall, GPU tuning.

### Design pipeline (R7, R11-R16)
- **Stack-agnostic scaffold + late architecture.** `/scaffold <general|experience>` creates the design doc
  as `Status: DRAFT`; the stack is decided late in `/forge`.
- **Layered docs**, each with exactly one writer: `DESIGN.md`/`TEDD.md` (contract, lockable) ->
  `STORIES.md` (`/scribe`) -> `TASKS.md` (`/blueprint`) -> `STATUS.md` (librarian-owned dashboard) plus
  `COMMANDS.md` (proven shell syntax) and `grades/` (report cards).
- **Contract layer** (`architect-agent`, `/forge contracts`): pins data formats, core-function semantics and
  invariants - each with a mandatory **worked example** that qa turns into the first unit test. Gates stop
  `/blueprint` from sharding, and `dev-agent` from implementing, an unpinned contract.
- `/librarian` cross-document audit with owner-tagged findings and git-recovery triage.

### Reliability (R13, R18-R20)
- **Git safety net**: scaffold initializes a repo; every passing unit is a checkpoint; a mangled file is
  restored from git, never hand-reconstructed.
- **Loop cost discipline**: per task only dev + qa run (was 5-8 subagent spawns), bookkeeping is the
  deterministic `close-unit.ps1` (tick, story roll-up, reindex, commit, verify), and grade + hygiene run at
  the story boundary.
- **The kit tests itself**: `test-kit.ps1` (44 cases) + CI on Windows - the validation gate, covering static
  hygiene, inventory/collision consistency, the secret scanner, and fixture runs of scaffold/upgrade/close-unit.
- **Secret hygiene**: `scan-secrets.ps1` (never prints matched values) installed as each project's
  pre-commit hook, standard allowlist markers honored, and a kit-owned `## Secrets` section in project
  CLAUDE.md - because `docs/` becomes a plaintext search index.

### Operations (R21)
- **`models.json`** is the single source of truth for models; `sync-models.ps1` generates the `-cc`
  Modelfiles and builds the variants. Adding a model is one JSON entry.
- **`ad-doctor.ps1`**: read-only readiness check for prerequisites, Ollama + declared models, the server's
  live MCP tool list, the global install, and a project's wiring.
- **`upgrade-project.ps1`**: retrofits an existing project to the current kit, refreshing kit-owned
  CLAUDE.md sections while preserving your Stack/Build/test.

### Sensors (R17)
- Images in `docs/` are captioned and audio optionally transcribed at index time (cached), so a whiteboard
  photo becomes searchable design context. `describe_image`, `detect_objects` (ONNX), `transcribe_audio`.
- Optional push-to-talk voice loop (`voice.py`, uv + faster-whisper + headless `claude -p`).

### Known limitations
- Windows-only scripting (the C# server itself is portable).
- `detect_objects` is compile-verified but not inference-verified; bring your own ONNX model.
- Quality depends on the local model: contract-pinning and `/blueprint` want the strongest model available.
