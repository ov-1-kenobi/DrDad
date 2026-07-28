# Subagents - your biggest context-window multiplier

A subagent is a *separate* Claude Code instance the main agent spawns to do a focused
job. It has its **own context window**, does its work, and returns only a short summary.
So it can read 10 files or search a datasheet 20 times and hand back 200 tokens - your
main session's 64K stays clean. On a small local context window this is the single most
effective mitigation.

## Two ways to use them

### 1. Built-in agents (no setup) - just ask
In the Claude Code panel, phrase the task so it delegates:
- "Use a subagent to find every place GPIO is configured and summarize the pin usage."
- "Explore the repo with a subagent and report the build/test setup, don't dump files."

Built-in types include **Explore** (read-only search), **general-purpose** (multi-step
research), and **Plan** (design a plan). The main agent picks one and only the summary
comes back.

### 2. Custom agents (reusable, scoped) - define once
Markdown files with YAML frontmatter + a system prompt, in `%USERPROFILE%\.claude\agents\`
(global) or `.claude/agents/` (per-project). **This kit installs ten globally** via
`install.ps1` (source in `global/agents/`): `requirements-agent`, `architect-agent`, `planner-agent`,
`dev-agent`, `grade-agent`, `qa-agent`, `doc-researcher`, `hygiene-agent`, `scribe-agent`,
`librarian-agent`. Example shape:

```markdown
---
name: doc-researcher
description: Cited lookups from the indexed docs (TEDD/datasheets). Use before implementing.
tools: Read, Grep, mcp__local-tools__search_datasheets, mcp__local-tools__list_datasheets
---
System prompt goes here...
```

- `name` - how you invoke it ("use the doc-researcher"). Under the hood every custom agent is launched via
  the **Task tool** with `subagent_type` = this name. Agents are NOT skills - a model that calls the Skill
  tool with an agent name gets "Unknown skill" (smaller local models make this mistake; the kit's commands
  now say the tool explicitly).
- `description` - when the main agent should reach for it automatically.
- `tools` - *optional* allow-list. Omit to inherit all tools. MCP tools are named
  `mcp__<server>__<tool>`; our server is `local-tools`, so e.g. `mcp__local-tools__search_datasheets`.
- `model` - *optional*. Pins this agent to a model (e.g. `model: qwen3-14b-cc`). With the local
  Ollama endpoint the name passes straight through. Caveat on 16 GB VRAM: mixing a big model
  (Next) with a small one across agents makes Ollama swap models in/out each hand-off - see the
  README "Per-agent models" note. Often simpler to switch the whole session with `use-model.ps1`.

### 3. Orchestrated (the `/build` command)
The orchestrator is the **main session**, not a nested agent (subagents don't call each other).
`/build` tells it to relay between the agents: requirements-agent -> dev-agent -> qa-agent, looping
until tests pass.

## Why this matters for your build loop

Pattern that keeps context lean while building:
1. Main agent owns the requirements + the code it's writing.
2. It delegates **lookups** ("what's the spec for X?") to `doc-researcher`, which burns *its*
   context searching the docs and returns just the answer.
3. It delegates **exploration** ("where is the init code?") to Explore.

The main agent stays focused on writing and testing, not on holding 300 pages of doc.

## Index discipline (every agent follows this)

The `local-tools` server keeps a searchable index of the project's docs (`<docs>/.index/chunks.json`),
and `search_datasheets` reads it fresh from disk on every call. Two rules the agents bake in:

1. **Read via the index.** Prefer `search_datasheets` / the `doc-researcher` over reading whole docs -
   it returns just the relevant passage and keeps each agent's small context window lean.
2. **Reindex after you change docs.** Any agent/command that writes to the docs corpus (a design doc,
   TEDD, ASSETS, ingested page) reindexes right after - `index_datasheets` (in-session, no path) or
   `reindex.cmd <docsDir>` (CLI) - so the NEXT agent's search sees the update, not a stale copy.
   `/forge`, `/proto`, `/build`, `/assets`, `/blueprint`, `/scribe`, the planner-agent, the scribe-agent, the requirements-agent, and the dev-agent all do this;
   read-only agents (`doc-researcher`, `qa-agent`, `grade-agent`) and the code-only `hygiene-agent` just
   search (`grade-agent` writes only its `grades/<id>_GRADE.md` report card, which lives outside `docs/`).
   (`ingest_url` reindexes itself; `LOCALTOOLS_AUTO_REINDEX=1` also auto-refreshes on staleness.)
