# Technical Experience Design (TEDD) - <experience>

Status: DRAFT
Security review: REQUIRED
<!-- REQUIRED | NOT-REQUIRED (<why>) | DONE <YYYY-MM-DD>. Decided in /design once the STACK is known;
     /design spawns security-agent when REQUIRED. /build REFUSES to start while this says REQUIRED.
     An experience is often legitimately NOT-REQUIRED - "local-only, no network, no user data" - but that
     is a DECISION with a reason, not an omission. It becomes REQUIRED the moment there is a leaderboard,
     an account, an upload, telemetry, or anything served over a network. -->
<!-- For experiences: interactive / game / XR / infographic / simulation. DRAFT = /design is shaping the
     vision / requirements / architecture / epics. LOCKED = the design is the CONTRACT; /spec and /build
     implement it. Stories live in STORIES.md and tasks in TASKS.md - editable even while this is LOCKED.
     Flip DRAFT <-> LOCKED with /design or /proto on your confirmation. -->

## Experience vision
<what the experience is, the feel, the audience, the core interaction or loop - NOT the tech>

## Requirements
<!-- What the experience must deliver + constraints (platforms, input, performance feel). Stack-agnostic.
     New requirements come back here (via /design), not into STORIES.md. -->
- R1: <requirement>

## Epics  (lightweight - coarse feature groups; optional for small projects)
<!-- Each epic is a chunk of the experience (a mode, a system, a level-family). Stories in STORIES.md
     trace to an epic by tag, e.g. "(Epic E1)". /stories expands epics into stories. -->
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

## Solution architecture (decided FIRST - /design step 2, before requirements and contracts)
<!-- Filled in /design STEP 2, before requirements and contracts: CLAUDE.md has no build/run command until
     an engine is chosen, so /build cannot verify anything, and the engine's docs cannot be ingested until
     it is known. /design proposes 2-3 engines/frameworks/platforms that FIT (it must not default to a
     favorite), YOU choose, and the choice + rationale go here. Then fill CLAUDE.md from the matching
     stack profile. -->- Chosen stack: <TBD>
- Rationale: <why it fits>
- Build / test / run: <filled from the chosen stack profile>

## Out of scope
- <not now>

<!-- Stories -> STORIES.md (managed by /stories).  Tasks -> TASKS.md (managed by /taskmap). -->
