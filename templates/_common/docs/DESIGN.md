# Design - <project>

Status: DRAFT
<!-- DRAFT = /forge is shaping requirements / architecture / epics. LOCKED = the design is the CONTRACT;
     /spec and /build implement against it. Stories live in STORIES.md and tasks in TASKS.md - those stay
     editable even while this is LOCKED (they implement the design, they do not redefine it). Flip DRAFT
     <-> LOCKED with /forge or /proto on your confirmation. -->

## Goal
<one paragraph: what this builds and why>

## Requirements
<!-- What the system must do + constraints. Numbered, testable where possible. Stack-agnostic (describe
     WHAT, not the tech). New requirements always come back here (via /forge), not into STORIES.md. -->
- R1: <requirement>

## Epics  (lightweight - coarse feature groups; optional for small projects)
<!-- Each epic is a chunk of work. Stories in STORIES.md trace to an epic by tag, e.g. "(Epic E1)".
     A small project can use a single epic or skip them. /scribe expands epics into stories. -->
### E1: <epic title>
- Scope: <one or two lines - what this epic covers>

## Contracts (pin BEFORE locking - the architect-agent writes these)
<!-- The load-bearing decisions: data formats, core-function semantics, invariants. The test: "could two
     reasonable devs implement this differently?" - then it MUST be pinned here, each with a WORKED
     EXAMPLE (dev models implement from examples; qa turns each example into the first unit test).
     A design with unpinned load-bearing contracts is NOT lock-ready. -->
### C1: <name>
- **Decision:** <chosen option>
- **Format / signature:** <exact data shape / byte layout / function signature + pre/post>
- **Invariant(s):** <what must always hold; crash-recovery rule>
- **Worked example:** <concrete input values -> operation -> exact expected output>
- **Out of scope:** <what this deliberately does not cover>

## Solution architecture (decide LATE - once requirements + epics are stable)
<!-- Do NOT pick a stack up front. When the design is solid, /forge proposes 2-3 architectures that FIT,
     you choose, and the choice + rationale go here. Then fill CLAUDE.md's stack + build/test/run +
     placeholder + human-in-loop from the matching stack profile (templates/<stack>). -->
- Chosen stack: <TBD>
- Rationale: <why it fits>
- Build / test / run: <filled from the chosen stack profile>

## Out of scope (for now)
- <explicitly not building yet>

<!-- Stories -> STORIES.md (managed by /scribe).  Tasks -> TASKS.md (managed by /blueprint). -->
