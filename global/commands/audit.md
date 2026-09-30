---
description: Audit cross-document consistency (DESIGN/STORIES/TASKS/grades/index) via the librarian-agent, then route each finding to its owner agent on your OK. Also triages git recovery for a mangled file.
argument-hint: [empty = full audit | status = refresh docs/STATUS.md | recover <file> = git triage]
---
**Record this audit's baseline BEFORE anything else.** In the target project run `git rev-parse HEAD` and
take the current UTC time as ISO 8601 with a Z, e.g.
`powershell -NoProfile -Command "(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')"`.
Hold both for the rest of the run as `$sinceCommit` / `$startTime`. Unlike `/build`'s scope, a full
`/audit` has no natural "start of work" range, so the baseline is simply "now" at audit start: the
files-touched / gate-interventions figures in the run summary reflect only what happens DURING this audit
run (routing fixes to owner agents), not prior history - and the summary should say so.

**FIRST, before spawning anything, GENERATE the state half of the audit:**
```
dad doc-stats -Findings
```
Those `STATE FINDINGS` are yours to route directly - they are computed, so they are true. The `STATE FACTS`
line is ground truth: **paste it verbatim into the librarian's prompt and tell it those facts may not be
contradicted.**

An audit on a healthy project once reported "DESIGN.md Status: LOCKED header missing" (line 5),
"STORIES.md missing `<!-- Status -->` markers for S2-S6" (all 14 had them) and "TASKS.md has 0 tasks with
[x]" (10 were ticked) - immediately after running this script, which had printed the real numbers. Saying
yes to those "fixes" would have rewritten a correct header and re-ticked ticked tasks. So this category is
no longer the librarian's to author. **Reject any `[design]`/`[scribe]`/`[taskmap]`/`[grade]` finding it
returns that contradicts the STATE FACTS**, and tell it so rather than acting on it.

**A claimed-missing CONTRACT must be checked, never believed:**
```
dad doc-stats -Contract <Cn>
```
Exit 0 means it exists, with its line number - the finding is wrong. (Same run claimed C2PA signing was
"not in the design contracts"; it is `C10-b`.) Use `-Contract *` to list them all before accepting any
"capability not in the design" claim.

**THEN update the dashboard:**
```
dad doc-stats -UpdateStatus
```
That writes the `## Snapshot` block of `docs/STATUS.md` deterministically and prints the numbers. Use
them verbatim from here on. A real audit once reported "STATUS.md refreshed with current progress
metrics" without ever running this - the dashboard said 1/1 stories on a project with 14. The librarian
owns the PROSE sections of STATUS; it does not compute counts and must not overwrite the Snapshot block.

**THEN produce the run summary:**
```
dad run-summary -ProjectDir <project> -SinceCommit <baseline sha> -StartTime <baseline time>
```
(the baseline recorded at audit start). Relay its output verbatim in the audit report, noting that it covers
only this audit run. If the baseline was forgotten, the script falls back to the session pointer window and
labels it `source: session start` - a labelled default, not an error. The summary is descriptive only and
never a gate.

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
