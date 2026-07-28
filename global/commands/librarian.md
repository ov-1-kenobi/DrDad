---
description: Audit cross-document consistency (DESIGN/STORIES/TASKS/grades/index) via the librarian-agent, then route each finding to its owner agent on your OK. Also triages git recovery for a mangled file.
argument-hint: [empty = full audit | status = refresh docs/STATUS.md | recover <file> = git triage]
---
Run the **librarian-agent** to keep the document set honest. Spawn it via the **Task tool**
(subagent_type: "librarian-agent") - it is an AGENT, not a skill; calling the Skill tool with an agent
name fails with "Unknown skill".

- **Empty / audit:** spawn it in **AUDIT** mode. Relay its compact tagged findings, then for each one I
  approve, ROUTE it to its owner - you are the orchestrator; the librarian never edits:
  - `[scribe]` -> scribe-agent (FIX that story)     - `[blueprint]` -> planner-agent (repair TASKS)
  - `[grade]` -> grade-agent (write the missing card) - `[dev]` -> dev-agent
  - `[forge]` -> tell me to run `/forge` (DESIGN edits need the unlock flow) - do not edit DESIGN here
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
