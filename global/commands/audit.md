---
description: Audit cross-document consistency (DESIGN/STORIES/TASKS/grades/index) via the librarian-agent, then route each finding to its owner agent on your OK. Also triages git recovery for a mangled file.
argument-hint: [empty = full audit | status = refresh docs/STATUS.md | recover <file> = git triage]
---
**FIRST, before spawning anything, generate the real counts:**
```
powershell -ExecutionPolicy Bypass -File "C:\Projects\Claude\MCP\DAD-kit\doc-stats.ps1" -UpdateStatus
```
That writes the `## Snapshot` block of `docs/STATUS.md` deterministically and prints the numbers. Use
them verbatim from here on. A real audit once reported "STATUS.md refreshed with current progress
metrics" without ever running this - the dashboard said 1/1 stories on a project with 14. The librarian
owns the PROSE sections of STATUS; it does not compute counts and must not overwrite the Snapshot block.

Run the **librarian-agent** to keep the document set honest. Spawn it via the **Task tool**
(subagent_type: "librarian-agent") - it is an AGENT, not a skill; calling the Skill tool with an agent
name fails with "Unknown skill".

**YOU do the fixing, not me.** You are the orchestrator and you have the Task tool. Never hand back a list
of "next actions you'll need to perform", never tell me to run an agent, and never invent a CLI for one
(there is no `grade-agent` executable and no `/grade`-per-unit loop to script). Spawn the owner agent
yourself, one finding at a time, and report what changed. Only `[human]` findings come back to me.

- **Empty / audit:** spawn it in **AUDIT** mode. Relay its compact tagged findings, then for each one I
  approve, ROUTE it to its owner - you are the orchestrator; the librarian never edits:
  - `[scribe]` -> scribe-agent (FIX that story)     - `[taskmap]` -> taskmap-agent (repair TASKS)
  - `[grade]` -> **one grade-agent per unit** (or `/grade <id>` repeatedly). NEVER ask one agent to card
    several units - it returns having written nothing. Verify each file after it is written.
  - `[dev]` -> dev-agent
  - `[design]` -> tell me to run `/design` (DESIGN edits need the unlock flow) - do not edit DESIGN here
  - `[git-recover]` -> librarian-agent in RECOVER mode, then run its restore command on my OK
  - `[index]` -> already fixed (reindexed) - just report it
- **`status`:** spawn the librarian-agent in **STATUS** mode - it regenerates `docs/STATUS.md` (the
  dashboard: done/next/blockers, derived from TASKS/STORIES/grades) and reindexes. Pass along any blockers
  I have mentioned so they get recorded. (A full audit refreshes STATUS automatically.)
- **`recover <file>`:** spawn the librarian-agent in **RECOVER <file>** mode; relay the last good commit +
  what a restore would lose + the exact command; run it only on my OK, then rebuild to confirm.

When to run: at the end of a `/build` scope (the orchestrator does this itself), after any interrupted or
messy session, or whenever the docs feel drifty.

**Be decisive - act, don't narrate.** Spawn the agent immediately; do not ask permission for read-only
steps. The WAIT points are my per-finding approvals and any restore command.
