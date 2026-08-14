---
description: RETRO mode - read the grade trends across all units, propose convention changes that stop the same defect recurring, and feed them back into CLAUDE.md / RECIPES.md on your approval.
argument-hint: [empty = full retro | apply = re-run after approving changes]
---
Close the loop. Grade cards are per-unit islands: each says how ONE story went, and nothing ever asks what
keeps going wrong ACROSS units - so the same defect gets found, written down, and found again three
stories later. This turns that record into changes to how the project works.

**Run it every 3-5 closed units, or whenever a build starts feeling like it is drifting.**

## 1. Get the numbers (computed - do not eyeball the cards)

```
powershell -ExecutionPolicy Bypass -File "C:\Projects\Claude\MCP\DAD-kit\grade-trends.ps1"
```

It reports grade direction, units that needed rework, stub cards, and **recurring themes** - a theme in
40%+ of cards is a convention problem, not bad luck. Use these numbers verbatim; they are ground truth and
you must not contradict them, same rule as `/audit`.

Also run, for the state half:
```
powershell -ExecutionPolicy Bypass -File "C:\Projects\Claude\MCP\DAD-kit\doc-stats.ps1" -Findings
```

## 2. Read the cards behind the top 2-3 themes

Only those. `search_datasheets` the theme, then read the specific cards. Do not read all of them - a retro
that consumes the whole context returns a summary instead of a change.

## 3. Propose changes - each one has to name what it PREVENTS

For each recurring theme, propose ONE concrete change, and say which cards it would have prevented:

- **A convention** -> a line in the project's `CLAUDE.md` (Stack / Build-test / hygiene section). This is
  the strongest form: every future agent reads CLAUDE.md, so a rule here applies before the defect happens.
- **A proven command** -> an entry in `docs/RECIPES.md` (Command / Does / When / Gotcha / Verified). Use
  this when the fix is "there is a way to do this that works on this machine".
- **A contract** -> `[design]`, routed to `/design` (needs unlock). Use when two units diverged because
  nothing pinned the shape.
- **A gate** -> tell me. If a defect keeps recurring and no prose will stop it, the honest answer is a
  script, and that is a change to the KIT, not to this project. Say so plainly rather than writing another
  paragraph of guidance nobody reads.

**Do not propose more than three changes.** A retro that rewrites the conventions wholesale is how a
project's CLAUDE.md becomes an unread wall, and an unread convention is worse than none - it looks like
the problem is handled.

## 4. WAIT for my approval, then apply

Relay the proposals with their evidence (theme, card count, which cards). I pick. Only then:
- edit `CLAUDE.md` (append to the right section - never rewrite kit-owned sections)
- append to `docs/RECIPES.md`
- route `[design]` items to `/design`
- reindex

Then re-run `grade-trends.ps1` and record in `docs/STATUS.md` under Notes what changed and why, so the
next retro can tell whether it worked.

## What this is for

The system drifts. Different models fail differently - one invents API signatures, one fabricates missing
contracts, one writes stub grade cards - and the drift is invisible from inside a single unit. The grade
record is the only place it accumulates.

**Watch for `direction: DEGRADING` in particular.** Grades getting worse across a project usually means the
conventions no longer match what is being built, or the model was switched. Say which you think it is -
and if a theme has survived a previous retro's convention change, do not write the convention again. It
did not work; escalate it as a gate.
