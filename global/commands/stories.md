---
description: Manage STORIES.md - expand the DESIGN epics into stories, normalize/dedupe, or migrate stories out of an old design doc. Small in-place edits, one story at a time, no whole-file reprints.
argument-hint: [audit | migrate | expand <epic> | <story id> | empty = audit]
---
Manage the story backlog in **STORIES.md** with the **scribe-agent** - safely, ONE story at a time, WITHOUT
rewriting the whole file (a full rewrite is what makes a local model loop and blow the output limit).
Spawn it via the **Task tool** (subagent_type: "scribe-agent") - it is an AGENT, not a skill.

STORIES.md IMPLEMENTS the DESIGN contract; it does NOT redefine requirements (that is `/design`). Anything
needing a new requirement -> back to `/design`. STORIES.md stays editable even while DESIGN is `LOCKED`.

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

Never paste the whole file into chat. STORIES only - design decisions belong in `/design`, task breakdown in
`/taskmap`.

## S1 IS A WALKING SKELETON, NOT A BUILD SKELETON

The FIRST story must prove the system end to end, however trivially: one request in, one response out,
through the real layers, with an integration test against a real store. NOT "create the solution with
warnings as errors" - that is build configuration, and it leaves every later story adding to a pile nobody
has assembled.

Measured: a project reached 183 passing unit tests across 12 building projects, with a TWENTY-LINE host and
zero integration tests, having never once served a request. Every part worked; the thing did not exist.

A walking skeleton makes every later story an extension of something that RUNS, and it makes close-unit's
test gate mean INTEGRATION from the very first close instead of mocks.