---
description: BROWNFIELD mode - reverse-engineer an EXISTING codebase into a design doc + stories, with every claim cited to a real file. Run before /design on a project the kit did not create.
argument-hint: [area to focus on; empty = the whole solution]
---
Turn a codebase that already exists into a design doc and a story backlog, so the rest of the kit can work
on it. This is the entry point for a project DAD did not scaffold.

Scope: **$ARGUMENTS**  (empty = the whole solution)

**The one rule: DESCRIBE, never invent.** Every statement about what this system does must cite a real
file - `(src/Foo/Bar.cs:42)`. A brownfield doc that describes an idealised version of the code is worse
than no doc, because every downstream agent will then implement against the fiction. If you cannot find
how something works, that is a FINDING ("cannot determine X"), not a gap to fill with a plausible guess.

## The loop

1. **Prove the shell and orient.**
   ```
   dad doc-stats
   ```
   Then `upgrade-project.cmd` if `docs/` is missing - this project may never have had one.

2. **Extract the real API surface** (this is why brownfield works here at all):
   ```
   dad api-surface
   ```
   Needs a successful build first. It writes `docs/API-SURFACE.md` - the EXACT public types and signatures
   of every assembly, read out of the compiled output. Contracts derived from that are derived from what
   the code actually is, not from what a model inferred from names.

3. **Spawn `survey-agent`** (Task tool, subagent_type: "survey-agent") **one AREA at a time** - a project,
   a namespace, a folder. It returns what that area does, its entry points, its data shapes, and its
   external dependencies, all cited. Relay each survey to me before moving on.

4. **Write `docs/DESIGN.md` as `Status: DRAFT`** from the surveys:
   - **Requirements** = what the system demonstrably does today, each cited. Mark anything you inferred
     from naming rather than read from logic as `(inferred)` - it is a question for me, not a fact.
   - **Contracts** = the data formats and semantics ALREADY in the code, pinned with a worked example
     taken from a real test or a real payload where one exists. Cite the type from `API-SURFACE.md`.
   - **Solution architecture** = the stack as it IS (versions from the project files, not aspiration).
   - **Known gaps** = what has no tests, what is stubbed, what looks abandoned. Do not soften this; it is
     the most useful section in a brownfield doc.

5. **Write `docs/STORIES.md` for the WORK REMAINING** - not for what already exists. A story per gap,
   defect or wanted change, each `<!-- Status: TODO -->`. Do NOT write stories describing finished
   functionality; the design doc records that, and a backlog full of already-done work makes every
   completion metric meaningless.

6. **GATE - the citations must resolve:**
   ```
   dad doc-stats -Findings
   ```
   plus re-read your own doc: every `(path:line)` must be a file that exists. A citation to a file that is
   not there is a fabrication, and it is the failure mode this whole mode is guarding against.
   Then reindex so the new docs are searchable.

7. **Hand off:** tell me to review DESIGN.md - especially anything marked `(inferred)` - then run `/design`
   to correct and extend it, and lock it when it matches reality. `/taskmap` and `/build` follow as normal.

## What NOT to do

- Do not refactor, reformat or "tidy" anything. This mode reads; it does not write code.
- Do not describe the whole system in one pass. One area per survey, relayed to me, or the context blows
  and you get a confident summary of nothing.
- Do not assume test coverage from the existence of a test project. **Count the tests** - a project with a
  csproj and no `[Fact]` is an empty shell, and a solution has shipped "all tests pass" over exactly that.
