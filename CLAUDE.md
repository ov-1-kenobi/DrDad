# Project: DrDad - Design Research Document, Agentic Development (kit maintenance)

This folder IS the **DrDad** kit (local, offline Claude Code). Editing it here maintains the kit itself.
(DrDad = the lightweight local runtime + design-doc loop; **BMAD on DrDad** = BMAD running on top of it.)

## Stack
- C# / .NET 8 (`RollForward=LatestMajor`, so it builds on .NET 8+ SDK and runs on .NET 8+ runtime)
  - the `local-tools` MCP server in `local-tools\`.
- PowerShell + `.cmd` - the installer and helper scripts.
- Markdown - templates, global commands/agents, and docs.

## Design docs
- Contract: `docs/DESIGN.md` (created by `/scaffold`; Status starts DRAFT) - requirements, epics, stack.
- Stories: `docs/STORIES.md` (created by `/stories`).  Tasks: `docs/TASKS.md` (created by `/taskmap`).
- Visual contract: `docs/STYLE.md` - palette / type / tone / branding for a UI project (`/design` fills it;
  ux-agent reviews surfaces against it; `doc-stats` WARNs when CSS drifts off the palette).
- Dashboard: `docs/STATUS.md` - done / next ready / blockers at a glance. READ IT FIRST when starting or
  resuming work. DERIVED (librarian-agent is its only writer; TASKS/STORIES/grades win on conflict) -
  refresh with `/audit status`; never hand-edit it or treat it as the source of truth.
- All indexed in `local-tools`; use `search_datasheets` / `doc-researcher`, cite them.

## Modes / flow  <- read this
If I haven't said which, ASK first. DESIGN's `Status:` header is the source of truth (it is the contract).
- `/design` - design-first: shape DESIGN - the STACK first (step 2), then the security review,
  requirements, epics, and contracts. No stories, no code.
- `/proto` - co-design: greybox + record dated decisions into DESIGN (DRAFT).
- `/stories` - manage STORIES.md: expand epics into stories, normalize, migrate. Write ONE story at a time
  as a succinct block. Stories are managed ATOMICALLY - the whole story lands or none of it; never
  overwrite/delete parts of other stories; keep numbering and ordering sequential and sensible.
- `/taskmap` - shard STORIES.md into `docs/TASKS.md` (bite-sized tasks + deps), reindexed. Optional.
- `/spec` - implement the LOCKED design faithfully (works a task/story); gaps -> questions.
- `/build [scope]` - per TASK: dev -> qa -> `close-unit.ps1` (which verifies the build, ticks, commits);
  per STORY: grade -> hygiene. Gated on DESIGN LOCKED and on CLAUDE.md having real build/test commands.
Docs: DESIGN.md/TEDD.md = contract (lockable) | STORIES.md = story backlog | TASKS.md = task map.
Lock scope: only DESIGN carries `Status:`; `/design` and `/proto` flip DRAFT <-> LOCKED on your confirmation.
STORIES.md and TASKS.md stay editable even while DESIGN is LOCKED. Never edit DESIGN prose when LOCKED; never `/spec` a DRAFT DESIGN.
Flow: /scaffold (DRAFT DESIGN) -> /design -> /stories -> (optional) /taskmap -> lock DESIGN -> /spec or /build.
**Invoking agents:** anything named `*-agent` (scribe-agent, taskmap-agent, dev-agent, librarian-agent, ...)
is a SUBAGENT - launch it with the **Task tool**, subagent_type = the agent's exact name. Agents are NOT
skills; NEVER call the Skill tool with an agent name (it will fail with "Unknown skill"). Do not enter
plan mode to run these commands - execute their steps directly; if you land in plan mode, exit it first.

## Build
- Build: `dotnet build local-tools\local-tools.csproj -c Release`
  -> produces `local-tools\bin\Release\net8.0\local-tools.exe` (what `.mcp.json` launches). This is the
  only compiled piece of the kit; `close-unit.ps1`'s `Get-ClaudeCommand 'Build'` parses this exact bullet
  label to verify a build before ticking a unit - without it, close-unit closes WITHOUT verification.
- Test: `powershell -NoProfile -ExecutionPolicy Bypass -File .\test-kit.ps1`
  -> the same suite as the validation gate below, parsed by `Get-ClaudeCommand 'Test'`. Until this bullet
  existed, closing a STORY here printed "closing WITHOUT tests" and verified the BUILD ONLY - the kit's own
  close gate was doing to itself exactly what the Build bullet's note warns about. close-unit refuses the
  close if the suite exits non-zero, and also if it reports ZERO tests (a green run of nothing verifies
  nothing). It runs the full suite deliberately, NOT `-SkipBuild`: the skip drops the MCP-server cases,
  which are the ones a C# change is most likely to break.

## Validation gate (run after ANY change; don't say "done" until it passes)
**Run the suite - that IS the gate:**
```
.\test-kit.ps1              (or test-kit.cmd; -SkipBuild for a fast docs/scripts-only pass)
```
It must print `0 failed`. It covers: PowerShell parse, config JSON, ASCII-only text, python helpers,
the dev-path placeholder, inventory consistency (uninstall lists vs actual command/agent files, agent
frontmatter names, agents referenced by commands existing, commands naming the Task tool, description
frontmatter), the secret scanner's behavior + the kit being credential-clean, `new-project` /
`upgrade-project` / `close-unit` behavior on fixtures, the `dotnet build`, the MCP server's advertised
tool list, and `--reindex`. CI runs the same script on Windows (`.github/workflows/kit-ci.yml`).
Add a `Test-Case` for any bug you fix here - that is how this gate stays useful.

## Conventions (do NOT break these)
- **Keep ALL kit text ASCII** (`.ps1`, `.cmd`, `.md`, `.json`): no em-dashes (use `-`), arrows (use `->`),
  or smart quotes. PS 5.1 misparses non-ASCII in scripts, and command/agent descriptions get mangled when
  `install` copies them and when shown in a cp437/cp1252 console. Use `->`, `-`, `<->`, straight quotes.
- **Preserve the dev-path placeholder** `C:\Projects\Claude\MCP\DAD-kit` in config files - `install.ps1`
  rewrites it to the real install location. Do NOT replace it with a hard-coded absolute path.
- **JSON config = no BOM** (Node/Claude Code reads it). Scripts that write JSON use UTF-8 without BOM.
- **Models live in `models.json`** - one entry per model (alias / `-cc` name / base tag / role / VRAM).
  `sync-models.ps1` GENERATES the Modelfiles (`FROM <model>` + `PARAMETER num_ctx`) because Ollama's
  default context is too small for the agent loop. Never hand-write a `.Modelfile`, and never hard-code a
  model list in a script - `use-model`, `install`, `uninstall` and `dad-doctor` all read the manifest.
- **Global commands/agents** live in `global\`; `install.ps1` copies them to `%USERPROFILE%\.claude\`.
  After editing them or the C# server, **re-run `install.cmd`**.
- **One C# server only** - do not add Node/Python MCP servers; native Claude Code + `local-tools` is the design.

## Working agreement
- Confirm values against the design doc; cite it. Never invent - missing info is a question.
- After each change: build + test. Don't say "done" until they pass. Keep changes small and scoped.
- **Git checkpoints:** the scaffold made an initial commit; every passing `/build`/`/spec` unit is
  committed. If a file gets mangled, restore it from git (`/audit recover <file>`) - NEVER
  hand-reconstruct a broken file from memory.
- **Scratch work goes in _tmp/** (gitignored, and dad tidy empties it) - NEVER scatter ad-hoc
SUMMARY/COMPLETE/NOTES files at the project root; state belongs in TASKS/STORIES/STATUS.
- **ONE status file:** `docs/STATUS.md` (librarian-written). NEVER create ad-hoc status/summary/notes
  files (root STATUS.md, BUILD_SUMMARY.md, NOTES.md, ...). Summaries go in chat; state goes in
  TASKS/STORIES/STATUS via their owners.

## Proven recipes (docs/RECIPES.md - all sessions AND subagents follow this)
- **Consult first:** before an unfamiliar shell operation, `search_datasheets` for it - RECIPES.md holds
  syntax that actually WORKED on this machine (models guess shell syntax differently; do not re-guess).
- **Record on success:** when a NEW command works - especially one that failed first and you found the
  working syntax - append a small entry (Command / Does / When / Gotcha / Verified date+model) to
  `docs/RECIPES.md`, then reindex (`index_datasheets`). Don't log routine re-runs; update entries instead.
- Never record secrets/tokens in it.

## Secrets (hard rules - a pre-commit hook enforces the last one)
- **Never put a real credential in this repo.** Not in `docs/` (everything there is chunked into a
  PLAINTEXT search index), not in `RECIPES.md`, not in a story/task/contract, not in a comment, not in
  chat. Reference secrets **by NAME only**: `AWS_PROFILE`, `AZURE_CLIENT_ID`, `MYAPI_TOKEN`.
- Real values live in **environment variables** or a **gitignored `.env`** (commit `.env.example` with
  empty values instead). Config files that hold secrets belong in `.gitignore`.
- Prefer platform-native auth over long-lived keys: AWS `aws sso login` + profiles / IAM roles;
  Azure `az login` + `DefaultAzureCredential` / Managed Identity; Windows Credential Manager or DPAPI for
  local API keys.
- If you (the agent) encounter what looks like a real secret in this repo or in output: **STOP, do not
  echo it, tell me** - it must be treated as exposed and rotated.
- `scan-secrets.ps1` runs as a pre-commit hook. If it blocks a commit, fix the file - do not
  `--no-verify` around it without telling me.

## Web / grounding
- Web search / URL lookup: use the `local-tools` `web_search` / `ingest_url` tools, NOT the built-in
  WebSearch/WebFetch (those need Anthropic and don't work against local Ollama). For grounding,
  `web_search` to find, then `ingest_url` to fetch + persist into the RAG.

## Hybrid: the local co-processor
- If this session is running in HYBRID mode (`dad doctor` reports it), an extra MCP tool exists:
  `local_generate`. It runs a LOCAL model on this machine's GPU - delegate BOUNDED, low-stakes generation
  to it to keep drudge-work off the cloud budget: a first-pass implementation guess you will review,
  synthetic test data / fixtures, throwaway boilerplate. It does not exist outside hybrid mode - never
  assume it is there; if the tool is absent, you are not in hybrid, and that is fine.
- Its output is a DRAFT, always prefixed `[LOCAL DRAFT - verify before use]`. Read it, correct it, or throw
  it away - never bank or ship it unverified, and never reach for it on reasoning that has to be right
  (a design decision, security-sensitive logic, anything a test cannot catch if it is subtly wrong). The
  gates in this project do not get a local-model exception.
