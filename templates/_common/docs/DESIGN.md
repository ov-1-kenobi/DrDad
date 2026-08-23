# Design - <project>

Status: DRAFT
<!-- DRAFT = /design is shaping requirements / architecture / epics. LOCKED = the design is the CONTRACT;
     /spec and /build implement against it. Stories live in STORIES.md and tasks in TASKS.md - those stay
     editable even while this is LOCKED (they implement the design, they do not redefine it). Flip DRAFT
     <-> LOCKED with /design or /proto on your confirmation. -->

Security review: REQUIRED
<!-- REQUIRED | NOT-REQUIRED (<why>) | DONE <YYYY-MM-DD>
     /design decides this once the STACK is known, and ASKS you. Default REQUIRED; a throwaway POC or a
     local-only tool can be NOT-REQUIRED with a stated reason. Anything that handles auth, user data,
     uploads, payments or is internet-facing stays REQUIRED.
     /build REFUSES to start while this says REQUIRED - because retrofitting auth and input handling after
     a dozen stories is how the insecure version ships. security-agent turns it into DONE by pinning
     CURRENT (<6 months old) framework and security guidance into "## Security decisions", with cited
     sources in SOURCES.md. -->

## Goal
<one paragraph: what this builds and why>

## Security decisions
<!-- Written by security-agent (via /design) once the stack is known; each decision cites a source in
     SOURCES.md with its fetch date. Recency matters here more than anywhere else - guidance older than
     ~6 months may name a deprecated API or a library that has since had a CVE. Empty is fine ONLY when
     the header above says NOT-REQUIRED. -->

- <decision, the library/pattern chosen, and why - with [Snnn]>

## Requirements
<!-- What the system must do + constraints. Numbered, testable where possible. Stack-agnostic (describe
     WHAT, not the tech). New requirements always come back here (via /design), not into STORIES.md. -->
- R1: <requirement>

## Epics  (lightweight - coarse feature groups; optional for small projects)
<!-- Each epic is a chunk of work. Stories in STORIES.md trace to an epic by tag, e.g. "(Epic E1)".
     A small project can use a single epic or skip them. /stories expands epics into stories. -->
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

## Solution architecture (decided FIRST - /design step 2, before requirements and contracts)
<!-- Filled in /design STEP 2, before requirements and contracts. Not because early commitment is ideal,
     but because everything downstream needs it: CLAUDE.md has no Build/test command until a stack exists,
     so /build Gate 1 refuses to start and close-unit can verify nothing; the contracts above name real
     library types anyway; and the library docs cannot be ingested until the libraries are known - which
     is how one project shipped 16 compile errors from guessed API calls. /design proposes 2-3
     architectures that FIT the requirements (it must not default to a favorite), YOU choose, and the
     choice + rationale go here. Then fill CLAUDE.md's stack + build/test/run + placeholder +
     human-in-loop from the matching stack profile (templates/<stack>). -->- Chosen stack: <TBD>
- Rationale: <why it fits>
- Build / test / run: <filled from the chosen stack profile>

## Out of scope (for now)
- <explicitly not building yet>

<!-- Stories -> STORIES.md (managed by /stories).  Tasks -> TASKS.md (managed by /taskmap). -->
