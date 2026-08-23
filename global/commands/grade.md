---
description: Grade ONE completed unit (story or task) into grades/<id>_GRADE.md via the grade-agent. Use to backfill a missing card.
argument-hint: [unit id, e.g. S4 or T3.1; empty = list DONE units with no card]
---
Grade a completed unit with the **grade-agent** (Task tool, subagent_type: "grade-agent" - an AGENT, not a
skill). `/build` grades at each story boundary; this command exists to BACKFILL a card that is missing, or
to re-grade after a fix.

Unit: **$ARGUMENTS**

- **If empty:** list the DONE units that have no real card yet - stories marked `<!-- Status: DONE -->` in
  `docs/STORIES.md` and `[x]` tasks in `docs/TASKS.md` whose `grades/<id>_GRADE.md` is missing or is a stub
  (under ~800 bytes, or lacking `## Grade history`). Show me that list and ask which to grade. Do NOT try to
  grade them all at once.
- **If a unit id is given:** spawn the grade-agent for **that ONE unit** and nothing else.

**ONE UNIT PER INVOCATION.** Never ask the grade-agent to card several units in a single call - it burns its
context reading many diffs and returns having written nothing. To backfill several, call this command
repeatedly (or spawn one grade-agent per unit, sequentially), verifying each file after it is written.

**Gate after each card:** the file must exist, be at least 800 bytes, and contain `## Grade history`,
`## Assessment` and `## Suggestions`. If not, send the agent back - a one-line "all criteria met" is not a
grade. Then commit it:
```
dad close-unit -Id <unit id> -Title "grade card" -RequireGrade
```

**Be decisive - act, don't narrate.** Spawn the agent yourself; never tell me to run an agent or invent a
CLI for it. There is no `grade-agent` executable - agents are spawned with the Task tool only.
