# Technical Experience Design (TEDD) - <experience>

Status: DRAFT
<!-- For experiences: interactive / game / XR / infographic / simulation. DRAFT = /forge is shaping the
     vision / requirements / architecture / epics. LOCKED = the design is the CONTRACT; /spec and /build
     implement it. Stories live in STORIES.md and tasks in TASKS.md - editable even while this is LOCKED.
     Flip DRAFT <-> LOCKED with /forge or /proto on your confirmation. -->

## Experience vision
<what the experience is, the feel, the audience, the core interaction or loop - NOT the tech>

## Requirements
<!-- What the experience must deliver + constraints (platforms, input, performance feel). Stack-agnostic.
     New requirements come back here (via /forge), not into STORIES.md. -->
- R1: <requirement>

## Epics  (lightweight - coarse feature groups; optional for small projects)
<!-- Each epic is a chunk of the experience (a mode, a system, a level-family). Stories in STORIES.md
     trace to an epic by tag, e.g. "(Epic E1)". /scribe expands epics into stories. -->
### E1: <epic title>
- Scope: <one or two lines>

## Contracts (pin BEFORE locking - the architect-agent writes these)
<!-- The load-bearing decisions: data/state formats, core mechanic semantics (damage formulas, save-file
     layout, interaction rules), invariants. If two devs could implement it differently, pin it here -
     each with a WORKED EXAMPLE (concrete inputs -> exact expected outcome). -->
### C1: <name>
- **Decision:** <chosen option>
- **Format / signature:** <exact data shape / formula / rule>
- **Invariant(s):** <what must always hold>
- **Worked example:** <concrete values -> exact expected outcome>
- **Out of scope:** <deliberately not covered>

## Solution architecture (decide LATE - once requirements + epics are stable)
<!-- Do NOT pick an engine/framework up front. When solid, /forge proposes 2-3 architectures that FIT
     (engine/framework/platform), you choose, and the choice + rationale go here. Then fill CLAUDE.md from
     the matching stack profile. -->
- Chosen stack: <TBD>
- Rationale: <why it fits>
- Build / test / run: <filled from the chosen stack profile>

## Out of scope
- <not now>

<!-- Stories -> STORIES.md (managed by /scribe).  Tasks -> TASKS.md (managed by /blueprint). -->
