---
description: Scaffold a new project deterministically (runs new-project.ps1 - reliable, no guesswork)
argument-hint: <general|experience>  (general software vs an interactive/game/XR experience)
---
Scaffold this project by RUNNING the kit's deterministic script. Do NOT hand-copy files - the script lays
down the DrDad structure AND creates the right design doc as `Status: DRAFT`.

Kit path: `C:\Projects\Claude\MCP\DAD-kit`   (install rewrites this to the real location)

First decide the project KIND (this picks the design doc; the STACK is decided FIRST inside `/design`):
- **general** -> `docs/DESIGN.md` - a general software project (CLI, service, app, library, ...).
- **experience** -> `docs/TEDD.md` - an interactive / game / XR / infographic / simulation experience.

If `$ARGUMENTS` doesn't already say which, ASK me general vs experience before running.

Run from the current project folder (it scaffolds into the current directory):
```
dad new-project $ARGUMENTS
```
After it runs, report exactly what it created (CLAUDE.md, .mcp.json, and `docs/DESIGN.md` or `docs/TEDD.md`
as DRAFT), then tell me to: approve the `local-tools` server, then run `/design` (design-first) or `/proto`
- they grow the DRAFT doc and decide the stack FIRST (which fills CLAUDE.md's build/test). Do NOT fill the
stack in yet.

(Tip: you can also run `new-project.cmd <general|experience>` directly in a terminal - same result, no model.)
