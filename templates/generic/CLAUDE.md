# Project: <name>

## Stack
<!-- Left blank on purpose - AD does NOT lock a platform at scaffold. /forge decides the stack LATE,
     once the stories are implementable, and fills this in (cribbed from templates/<stack>). -->
- Language / runtime: <decided in /forge's architecture step>
- Key tools / libraries: <decided then>

## Modes / flow  <- read this
If I haven't said which, ASK first. DESIGN's `Status:` header is the source of truth (it is the contract).
- `/forge` - design-first: shape DESIGN (requirements, epics, stack decided LATE). No stories, no code.
- `/proto` - co-design: greybox + record dated decisions into DESIGN (DRAFT).
- `/scribe` - manage STORIES.md: expand epics into stories, normalize, migrate. Write ONE story at a time
  as a succinct block. Stories are managed ATOMICALLY - the whole story lands or none of it; never
  overwrite/delete parts of other stories; keep numbering and ordering sequential and sensible.
- `/blueprint` - shard STORIES.md into `docs/TASKS.md` (bite-sized tasks + deps), reindexed. Optional.
- `/spec` - implement the LOCKED design faithfully (works a task/story); gaps -> questions.
- `/build [scope]` - orchestrate requirements -> dev -> grade -> hygiene -> qa; gated on DESIGN LOCKED.
Docs: DESIGN.md/TEDD.md = contract (lockable) | STORIES.md = story backlog | TASKS.md = task map.
Lock scope: only DESIGN carries `Status:`; `/forge` and `/proto` flip DRAFT <-> LOCKED on your confirmation.
STORIES.md and TASKS.md stay editable even while DESIGN is LOCKED. Never edit DESIGN prose when LOCKED; never `/spec` a DRAFT DESIGN.
Flow: /scaffold (DRAFT DESIGN) -> /forge -> /scribe -> (optional) /blueprint -> lock DESIGN -> /spec or /build.
**Invoking agents:** anything named `*-agent` (scribe-agent, planner-agent, dev-agent, librarian-agent, ...)
is a SUBAGENT - launch it with the **Task tool**, subagent_type = the agent's exact name. Agents are NOT
skills; NEVER call the Skill tool with an agent name (it will fail with "Unknown skill"). Do not enter
plan mode to run these commands - execute their steps directly; if you land in plan mode, exit it first.

## Design docs
- Contract: __DESIGN_DOC__ (created by `/scaffold`; Status starts DRAFT) - requirements, epics, stack.
- Stories: `docs/STORIES.md` (created by `/scribe`).  Tasks: `docs/TASKS.md` (created by `/blueprint`).
- Dashboard: `docs/STATUS.md` - done / next ready / blockers at a glance. READ IT FIRST when starting or
  resuming work. DERIVED (librarian-agent is its only writer; TASKS/STORIES/grades win on conflict) -
  refresh with `/librarian status`; never hand-edit it or treat it as the source of truth.
- All indexed in `local-tools`; use `search_datasheets` / `doc-researcher`, cite them.

## Proven commands (docs/COMMANDS.md - all sessions AND subagents follow this)
- **Consult first:** before an unfamiliar shell operation, `search_datasheets` for it - COMMANDS.md holds
  syntax that actually WORKED on this machine (models guess shell syntax differently; do not re-guess).
- **Record on success:** when a NEW command works - especially one that failed first and you found the
  working syntax - append a small entry (Command / Does / When / Gotcha / Verified date+model) to
  `docs/COMMANDS.md`, then reindex (`index_datasheets`). Don't log routine re-runs; update entries instead.
- Never record secrets/tokens in it.

## Placeholder convention
- <how to stub unfinished/external pieces - e.g. interfaces + mocks; mark with TODO>

## Build / test
<!-- Filled by /forge once the stack is chosen (cribbed from templates/<stack>). -->
- Build: `<set in /forge's architecture step>`
- Test:  `<set in /forge's architecture step>`

## Human-in-loop
- <manual/verification steps, or "none">

## Secrets (hard rules - a pre-commit hook enforces the last one)
- **Never put a real credential in this repo.** Not in `docs/` (everything there is chunked into a
  PLAINTEXT search index), not in `COMMANDS.md`, not in a story/task/contract, not in a comment, not in
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

## Working agreement
- Confirm values against the design doc; cite it. Never invent - missing info is a question.
- After each change: build + test. Don't say "done" until they pass. Keep changes small and scoped.
- **Git checkpoints:** the scaffold made an initial commit; every passing `/build`/`/spec` unit is
  committed. If a file gets mangled, restore it from git (`/librarian recover <file>`) - NEVER
  hand-reconstruct a broken file from memory.
- **ONE status file:** `docs/STATUS.md` (librarian-written). NEVER create ad-hoc status/summary/notes
  files (root STATUS.md, BUILD_SUMMARY.md, NOTES.md, ...). Summaries go in chat; state goes in
  TASKS/STORIES/STATUS via their owners.
