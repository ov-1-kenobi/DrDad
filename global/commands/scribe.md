---
description: Manage STORIES.md - expand the DESIGN epics into stories, normalize/dedupe, or migrate stories out of an old design doc. Small in-place edits, one story at a time, no whole-file reprints.
argument-hint: [audit | migrate | expand <epic> | <story id> | empty = audit]
---
Manage the story backlog in **STORIES.md** with the **scribe-agent** - safely, ONE story at a time, WITHOUT
rewriting the whole file (a full rewrite is what makes a local model loop and blow the output limit).
Spawn it via the **Task tool** (subagent_type: "scribe-agent") - it is an AGENT, not a skill.

STORIES.md IMPLEMENTS the DESIGN contract; it does NOT redefine requirements (that is `/forge`). Anything
needing a new requirement -> back to `/forge`. STORIES.md stays editable even while DESIGN is `LOCKED`.

Read `CLAUDE.md` for the doc paths. If `docs/STORIES.md` does not exist, the scribe-agent creates it from
`templates/_common/docs/STORIES.md` first.

Pick the mode from **$ARGUMENTS**:
- **empty / `audit`** -> scribe-agent AUDIT: compact list of stories + problems + suggested fix order. Relay
  it, then WAIT for me to pick what to fix (or say "go" to fix in order).
- **`migrate`** -> scribe-agent MIGRATE: older project with stories still inside DESIGN.md/TEDD.md; it lifts
  them into STORIES.md (tagging each to an epic) ONE at a time and removes them from the design doc.
- **`expand <epic>`** (e.g. `expand E1`) -> scribe-agent EXPAND: draft the stories that epic implies into
  STORIES.md, one at a time.
- **a story id** (e.g. `S3`) or **"go"** -> scribe-agent FIX: normalize/create that story via small Edit
  calls, reindex, return a <=3-line summary. Then next / WAIT per my instruction.

Never paste the whole file into chat. STORIES only - design decisions belong in `/forge`, task breakdown in
`/blueprint`.
