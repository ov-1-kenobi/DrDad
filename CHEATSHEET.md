# DAD Cheatsheet - Design Document Aligned Development (RTX 5080 + Ollama)
> The design document is the contract; every mode aligns to it.

## Models

**Keep-it-straight map (alias -> model -> use):**
- **`oss`     -> gpt-oss-20b (MoE)** - THE planner: `/design`, `/stories`, `/audit`. Most literal.
- **`dev`     -> Devstral 24B** - GPU-resident, FAST; daily iteration, `/proto`, quick `/spec`, no CJK.
- **`fast`    -> 14B (Qwen)** - snappy light edits.
- **`quality` -> Next (Qwen 80B)** - most capable; **default for `/build`** and hard `/spec`. Slower (RAM-offload).

> Workflow: **gpt-oss (`oss`)** to design -> **Next (`quality`)** for hands-off `/build` & hard `/spec` ->
> drop to **Devstral (`dev`)** for fast iteration, **14B (`fast`)** for trivial edits.

Switch with the scripts below, then **start a NEW Claude Code session** (this build has no `/model` chooser).

| Model (Ollama tag)     | What it is                         | Best at                          | Select with        |
|------------------------|------------------------------------|----------------------------------|--------------------|
| `qwen3-coder-next-cc`  | 80B-A3B Next (offloads to RAM)     | **DEFAULT for /build** + hard /spec; most capable | `use-quality.cmd`  |
| `devstral-cc`          | Devstral 24B, fits GPU (EU/Apache) | **fast** iteration, /proto, quick /spec, no CJK | `use-model.cmd dev` |
| `gpt-oss-20b-cc`       | ~21B MoE (A3.6B), smallest reasoner | **planning** - /design, /stories, /audit | `use-model.cmd oss` |
| `qwen3-14b-cc`         | dense 14B, fully on GPU, fastest   | quick light edits                | `use-fast.cmd`     |
| any tag you built      | e.g. a custom `-cc`                | as needed                        | `use-model.cmd <name>` |

Not chat models (don't switch to these - used automatically): `nomic-embed-text` (RAG embeddings),
`gemma3:4b` (small/fast background helper).

Rule of thumb: **Next (`quality`) for `/build` & hard `/spec`** - most capable, best tools, worth the
offload when you fire-and-forget. **Devstral (`dev`)** for fast GPU-resident iteration. **gpt-oss (`oss`)**
for `/design`, `/stories`, `/audit`. **14B (`fast`)** for snappy light edits.

## Switching
```
use-quality.cmd          -> qwen3-coder-next-cc   (DEFAULT for /build + hard /spec: most capable)
use-model.cmd dev        -> devstral-cc          (fast iteration coding, /proto, quick /spec)
use-model.cmd oss        -> gpt-oss-20b-cc       (planning: /design / /stories / /audit)
use-fast.cmd             -> qwen3-14b-cc          (fast / light edits)
use-model.cmd <name>     -> any Ollama tag
```
Then start a new session / reload the VS Code extension. First message after a switch pays Ollama's
model-load time; `OLLAMA_KEEP_ALIVE=30m` keeps it warm after.

## Modes / commands
| Command            | Does                                                        | Model           | When                          |
|--------------------|-------------------------------------------------------------|-----------------|-------------------------------|
| `/scaffold <kind>` | **Stack-agnostic** DAD init: CLAUDE.md/.mcp.json/docs + the design doc as **DRAFT**. `kind` = general (`DESIGN.md`) or experience (`TEDD.md`); no stack chosen. `new-project.cmd <kind>` is the same. | either | starting a project |
| `/design [topic]`   | **Design-first**: stack FIRST, then requirements + epics + **contracts** (architect-agent pins formats/semantics with worked examples; `contracts` arg = just that step); NO stories/code; offers to LOCK | **oss**; **quality**/cloud for contracts | plan before building |
| `/stories [arg]`    | Manage **STORIES.md**: expand epics into stories, normalize/dedupe, `migrate` old in-doc stories out | **oss**/quality | build the story backlog |
| `/taskmap [story]` | Shard **STORIES.md** -> dependency-ordered bite-sized **task map** (`docs/TASKS.md`), reindex | **quality** (Next) | after /stories, before /build or /spec |
| `/proto [idea]`    | Build-as-you-go greybox + document decisions                | **dev**         | firing from the hip           |
| `/spec [item]`     | Implement the **LOCKED** design (works a task/story)        | **dev**         | spec is ready, build it       |
| `/build [scope]`   | Per task: **dev -> qa -> `close-unit.ps1`**. Per story: **grade -> hygiene**. Scripted close-out (tick/roll-up/reindex/commit/verify) | **coder**/**quality** | hands-off build+test |
| `/assets [scope]`  | (Unity) regenerate the art/asset list from the TEDD         | either          | refresh Unity asset list      |
| `/tidy [scope]`    | hygiene-agent: lint/format + project-file & dependency integrity, re-build | **dev** | tidy/verify after changes |
| `/diagram [focus]` | Mermaid architecture view of DESIGN.md -> `docs/ARCHITECTURE.md` (offline, diagram-as-code) | either | visualize the architecture |
| `/audit [recover <file>]` | Cross-doc audit (schema/traceability/DONE-rollups/grade cards), findings routed to owner agents; `recover` = git triage for a mangled file | **oss**/dev | after /build scope; messy sessions |

Scaffold is stack-agnostic. The STACK is chosen in `/design` step 2 - EARLY - cribbed from a
profile fragment `templates/<stack>/PROFILE.md` (dotnet | avalonia | python | embedded | unity).
(`templates/generic/CLAUDE.md` is the always-installed base, not a stack profile.)

## The pipeline
```
/scaffold <general|experience>   (stack-agnostic: CLAUDE.md + .mcp.json + docs/ + DESIGN as DRAFT)
  ->  /design     (DESIGN: stack FIRST -> fills CLAUDE.md, then requirements + epics + contracts; offers to LOCK)
  ->  /stories    (expand epics into stories -> STORIES.md)
  ->  /taskmap (optional: shard STORIES.md into TASKS.md - bite-sized tasks + deps, indexed)
  ->  lock DESIGN, then /spec  OR  /build   (implement; works the next ready task if TASKS.md exists)
  ->  you verify (run it; report back)
(/proto is the lightweight alt to /design+/stories: co-design DESIGN + jot stories as you go.)
```
Model per phase: **oss** (gpt-oss) for /design, /stories, /audit; **quality** (Next) for /taskmap, /build and hard /spec; **dev** (Devstral) for fast /proto and iteration.

`/build` cost discipline: **per TASK only dev + qa run**, then `close-unit.ps1` does the bookkeeping
deterministically. **grade + hygiene run per STORY** (grade card = `grades/<story id>_GRADE.md`), which cut
per-unit agent spawns from 5-8 to 2. To pin the grader to its own model, add `model: <tag>-cc` to
`agents/grade-agent.md`.

## Design-doc status header (gates the modes)
`/scaffold` creates DESIGN (`docs/DESIGN.md` or `docs/TEDD.md`) as `Status: DRAFT`. **Only DESIGN carries
Status**; `STORIES.md` (`/stories`) and `TASKS.md` (`/taskmap`) are working docs, editable even while LOCKED.
`docs/RECIPES.md` (created by `/scaffold`) is the proven-commands log: agents search it for shell syntax
that worked on this machine and append new successes (then reindex).
`docs/STATUS.md` (created by `/scaffold`) is the dashboard - done/next/blockers; librarian-owned + derived.
Read it first when resuming; refresh with `/audit status`.
- `Status: DRAFT`  -> `/design` and `/proto` may edit it; `/spec` will offer to lock first.
- `Status: LOCKED` -> `/spec` and `/build` implement it; the doc is read-only.
- **Flipping it:** `/design` and `/proto` set LOCKED (when ready) or unlock to DRAFT (to edit) **on your
  confirmation** - they edit the header for you. You don't have to hand-edit it.

## MCP tools (the `local-tools` server = document search, NOT build/test)
| Tool                       | Does                                              |
|----------------------------|---------------------------------------------------|
| `index_datasheets`         | (re)build the search index                        |
| `search_datasheets "q"`    | semantic search over the project's docs           |
| `list_datasheets`          | list the corpus files                             |
| `ingest_url <url>`         | ONLINE: fetch a page/PDF into the corpus + reindex|
| `describe_image <path>`    | OFFLINE-OK: read a whiteboard photo / screenshot with a local vision model (default `gemma3:4b`) -> text |
| `detect_objects <path>`    | OFFLINE-OK: WHERE things are - ONNX detector -> labels + pixel boxes (needs `LOCALTOOLS_DETECT_MODEL`) |
| `transcribe_audio <path>`  | OFFLINE-OK: recording -> timestamped text (local Whisper via uv)   |

Images dropped in `docs/` are auto-captioned into the index; audio too with `LOCALTOOLS_TRANSCRIBE_AUDIO=1`.
So a whiteboard photo becomes searchable design context.
| `web_search "q"`           | ONLINE: keyless DuckDuckGo search                 |

**Build/test is via the shell** (Unity CLI / `dotnet test` / `pytest` per the project's CLAUDE.md) -
never via `local-tools`. If the model claims otherwise, it's confused - point it at CLAUDE.md's commands.

## Utility
| Command / setting                              | Does                                                    |
|------------------------------------------------|---------------------------------------------------------|
| `install.cmd`                                  | (re)install the kit globally; re-run after kit changes  |
| `reindex.cmd <docsDir>`                        | rebuild a project's index from CLI / a scheduled task   |
| `voice.cmd` (run from the project folder)      | push-to-talk voice loop: whisper STT -> `claude -p` -> TTS (needs uv) |
| `upgrade-project.cmd [dir]`                    | retrofit an existing project to the current kit (docs, git, CLAUDE.md refresh) |
| `dad-doctor.cmd [-ProjectDir x]`                | **readiness check**: prereqs, Ollama+models, server, install, project wiring |
| `sync-models.cmd [-Report\|-All\|-Only a]`     | reconcile Ollama with `models.json` (pull bases, build the `-cc` variants) |
| `test-kit.cmd`                                 | run the kit's own test suite - the validation gate after any kit change |
| `dad-guard.cmd -Check` / `-Ack`             | stop guard: would a turn be blocked for unverified code? / accept it anyway |
| `scan-secrets.cmd [-Path x \| -Staged]`        | scan for credentials (also installed as each project's pre-commit hook) |
| `LOCALTOOLS_AUTO_REINDEX=1` (in proj .mcp.json)| auto-refresh the index when docs change                 |
| `/mcp` (inside Claude Code)                    | check `local-tools` is connected + its tools            |
| `ollama ps`                                    | confirm the model is on the GPU (vs CPU offload)        |

## Quick decision guide
- /build, hard /spec (hands-off, capability)       -> **quality** Next (`use-quality.cmd`)
- Fast coding iteration / /proto                   -> **dev** Devstral (`use-model.cmd dev`)
- Design / /stories / /audit                       -> **oss** gpt-oss-20b (`use-model.cmd oss`)
- Snappy light edits                               -> **fast** 14B (`use-fast.cmd`)
