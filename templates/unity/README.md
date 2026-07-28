# Project template (copy this into a new game/prototype)

A ready skeleton for the spec/proto/build workflow with a per-project doc corpus (Option A).
The **commands and agents are installed globally** (once, by `install.ps1`), so a
project only needs the things below.

## What's per-project (this template)
```
<your project>/
  CLAUDE.md          always-loaded project rules + Modes section + build/test commands
  .mcp.json          per-project corpus (edit LOCALTOOLS_DOCS_DIR -> this project's docs)
  docs/
    TEDD.md          your spec; the "Status:" header gates spec vs proto
    ASSETS.md        art/asset list; regenerate from the TEDD with /assets
    .index/          auto-generated vectors (gitignore it)
  Assets/Editor/
    BuildScript.cs   headless build entry point (BuildScript.PerformBuild)
```

## What's global (installed once by install.ps1 -> %USERPROFILE%\.claude\)
- Commands: **/scaffold**, **/spec**, **/proto**, **/build**, **/assets**
- Agents: **requirements-agent**, **dev-agent**, **qa-agent**, **doc-researcher**

These work in every project automatically - you do NOT copy them per project.

## Setup a new project (~1 min)
1. Copy `CLAUDE.md`, `.mcp.json`, and `docs/` into your project root.
2. In `.mcp.json`, set `LOCALTOOLS_DOCS_DIR` to this project's `docs` folder (and confirm the
   `command` path points at your built `local-tools.exe`).
3. Fill in `CLAUDE.md` (Unity version, build/test commands).
4. Put your TEDD in `docs/TEDD.md`; set its `Status:` (DRAFT to co-design, LOCKED to implement).
5. In Claude Code: run `index_datasheets`, then `/proto`, `/spec`, or `/build`.

## The commands
- **/proto [idea]** - co-design interactively; TEDD is a DRAFT it updates with dated decisions.
- **/spec [system]** - implement a LOCKED TEDD faithfully; gaps become questions; hands you
  Manual Editor Steps + Visual Inspection checklists.
- **/build [scope]** - orchestrated pipeline: requirements-agent -> dev-agent -> qa-agent, looping
  until tests pass. Mode follows the TEDD `Status:` (LOCKED=spec, DRAFT=proto).
- **/assets [scope]** - (re)generate `docs/ASSETS.md` (the art/asset list) from the TEDD.

Lifecycle: `/proto` (or `/build` on a DRAFT) grows the TEDD -> flip `Status: LOCKED` -> `/spec` or
`/build` implements it.
