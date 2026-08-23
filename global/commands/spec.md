---
description: SPEC mode - implement the locked design doc faithfully (agent leads, you execute)
argument-hint: [item/feature to build next; empty = next unbuilt item]
---
We are in **SPEC mode**.

**Be decisive - act, don't narrate.** Call tools and make the edits immediately; do not ask permission
for read-only steps (Read/Grep/search) or for the project's build/test commands, and do not describe what
you would do instead of doing it. (The WAIT at the end is only for my confirmation.)

Read `CLAUDE.md` first for THIS project's: design-doc path (default `docs/DESIGN.md`), build
command, test command, placeholder/stub convention, and human-verification steps. If the Stack / Build /
test are still placeholders (architecture not decided in `/design`), STOP and tell me to finish `/design`'s
architecture step first.

Rules:
- DESIGN.md/TEDD.md is LOCKED and authoritative. Do NOT edit the DESIGN prose. Stories live in STORIES.md
  and tasks in TASKS.md - those stay editable (they implement the design). Ticking a story's
  `<!-- Status: DONE -->` in STORIES.md or a task box in TASKS.md is progress-tracking, not a design edit.
- If its header isn't `Status: LOCKED`, OFFER to set it to `LOCKED` (on my OK, flip the header + reindex),
  or suggest `/proto` if the design isn't ready. Do not implement against a DRAFT without locking first.
- Don't invent or "improve" the design. Ambiguity/gaps are QUESTIONS for me, not your decisions.

Target: **$ARGUMENTS**  (empty = the next ready task, or unbuilt story if no task map)

Units come from TASKS.md / STORIES.md. If `docs/TASKS.md` exists (from `/taskmap`), target the next
UNCHECKED task in `## Build order` whose dependencies are all `[x]` (a smaller, self-contained unit);
otherwise the next unbuilt story in `docs/STORIES.md`.

1. Use the `doc-researcher` subagent (Task tool, subagent_type: "doc-researcher" - not a skill) /
   `search_datasheets` to pull the exact spec; cite the section.
   (The docs are indexed - search for the specific fact instead of reading whole files; keeps context lean.)
2. Implement it in the project's language/stack, using the placeholder convention from CLAUDE.md.
3. Build with CLAUDE.md's build command; fix errors.
4. List gaps as numbered questions; stop on blocking gaps.
5. If CLAUDE.md defines human-verification steps (editor wiring, hardware flash, manual smoke),
   produce that checklist; otherwise say "no manual steps."
6. Run the tests (CLAUDE.md's test command). On PASS, **close out by RUNNING the script** (it ticks the
   task, rolls the story up when all its tasks are done, reindexes, commits, and verifies):
   ```
   dad close-unit -Id <unit id> -Title "<short title>"
   ```
   Non-zero exit = not closed; fix what it reports. Then WAIT for my confirmation before the next item.
   (If a file got mangled: restore via `/audit recover <file>` - never hand-reconstruct it.)
