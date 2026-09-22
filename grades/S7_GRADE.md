# Story S7 - Ask-time scope pricing - state the cost before scope grows : report card

**Current grade: B+**  (as of 2026-09-22, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-22        | B+    | initial implementation (T7.1, T7.2, T7.3; commits 49509a1, 6c364a5, e8b8320) |

## Assessment (this iteration)

- **Correctness vs intent:** Matches the Goal precisely. `global\commands\stories.md`'s expand loop gained
  step **2b** (`global\commands\stories.md:103-115`) that diffs the before/after story-count snapshot and
  states the C1c Trigger-1 sentence, WAITing for the human before continuing ("WAIT for the human's explicit
  answer before moving to step 3", line 104). `global\commands\design.md`'s requirement/epic-capture flow
  gained step **4b** (`global\commands\design.md:96-109`) stating the C1c Trigger-2 sentence for a
  newly-added requirement/epic with no stories yet, explicitly saying the cost is "not priced yet" rather
  than inventing one (line 105 in that block: "Its stories aren't priced yet"). Both insertions are small,
  targeted, and use the SAME letter-suffix numbering convention design.md already used for its 2b (security
  review) step - not a structural departure.

- **Acceptance coverage:**
  - **AC1 - covered.** `stories.md:103-115` (step 2b) contains the real-count delta sentence
    (`"{unit} {id} added ~{deltaStories} stor(y/ies)..."`, lines 110-112) plus the explicit build-vs-keep-
    scoping question, positioned exactly where the next unit's scribe-agent would be spawned (before step 3,
    "Next epic - a FRESH agent", line 116).
  - **AC2 - covered.** `design.md:96-109` (step 4b) contains the epic/requirement-count-only sentence
    (`"Adding {unit} {id} (...) brings the design to {unitCount} {unit-plural}. Its stories aren't priced
    yet..."`, lines 105-107), and explicitly instructs "do NOT fabricate a story-count estimate" (line 99).
  - **AC3 - KNOWINGLY INCOMPLETE, correctly flagged rather than silently skipped.** Per T7.3's own Context
    (`docs\TASKS.md:428-432`, "If this task's execution environment cannot run the real installer against a
    live `~/.claude`, note explicitly... that this step is outstanding... do not silently skip it"),
    re-running `install.cmd` was deferred because it mutates state OUTSIDE this project
    (`%USERPROFILE%\.claude\`) and R35 (this kit's own convention, `docs\DESIGN.md:357-375`) requires
    explicit human consent before an outside-project action runs live. This is the correct call per R35(b).
    **Gap I can independently confirm:** I could not find an in-repo "completion record" that actually
    states the deferral happened - Story S1 sets the precedent (`docs\STORIES.md:12-23`, an
    `<!-- Implemented: ... -->` note describing exactly what was/was not live-verified and why), but Story
    S7's header in `docs\STORIES.md:261` carries no equivalent note, `docs\TASKS.md`'s T7.3 block
    (`docs\TASKS.md:415-440`) still reads as the original task spec (not annotated after the fact), and no
    `docs\STATUS.md` exists in this repo to carry it either. The instruction to record the deferral was
    followed in SPIRIT (the orchestrator told me the deferral happened and why) but I found no durable
    written trace of it in the project's own files - see suggestion 1 below.
  - **AC4 - Code-review-only verification.** `test-kit.ps1:4450-4460` has the new `Test-Case` ("S7's
    pricing-sentence language landed in both stories.md and design.md"), asserting `stories.md` matches
    `"keep scoping the next"` and `"Build what's already\s+scoped"`, and `design.md` matches
    `"aren't\s+priced yet"`. I hand-verified these regexes against the actual inserted text
    (`stories.md:110-112`, `design.md:105-106`) and they match correctly, including across the line-wraps
    (`\s+` spans the newline). I did **not** run `test-kit.ps1` myself (no shell tool available to this
    grading pass) so "prints 0 failed" is not independently confirmed - this is a code-review-only check on
    my part, not a defect in the implementation.

- **Design adherence:** Strong. Both sentences are verbatim-shape matches to `docs\DESIGN.md` Contract C1c
  (`docs\DESIGN.md:469-500`), correctly generalizing C1c's `{epic}`-flavoured worked example into `{unit}`/
  `{id}` per C1c's own instruction to adapt to "this kit's own vocabulary (a new Requirement, not an epic)
  rather than copying 'epic' language verbatim into a kit that has none" (`docs\DESIGN.md:274`). No scope
  creep - only `stories.md`, `design.md`, `test-kit.ps1` touched, matching the story's Data/interfaces list.

- **Quality:** Prose insertions read naturally in context and reuse existing structural idioms (the `2b`/`4b`
  letter-suffix sub-step pattern already established by design.md's own `2b` security-review step). The
  Test-Case follows the file's existing prompt-content-check pattern (e.g. the HYBRID-mode Test-Cases
  immediately preceding it at `test-kit.ps1:4407-4448`) rather than inventing a new style.

- **Hygiene:** No stray files, no dead code (this is prompt text, not code). One process gap: the "outstanding
  install.cmd" note that T7.3's own Context explicitly called for was not actually written into any tracked
  doc (STORIES.md/TASKS.md/STATUS.md) - see suggestion 1.

- **Verification mode (AC3/AC4 touch real machine state or unverifiable-without-shell facts):**
  - AC3 (installed copies in `%USERPROFILE%\.claude\commands\` refreshed): **Code-review-only, by design** -
    per the human's explicit instruction for this grading pass and per R35(b) (`docs\DESIGN.md:357-375`),
    running `install.cmd` live against the real `~/.claude` requires explicit human consent that has not yet
    been given in this session. Not verified live; correctly NOT run rather than silently skipped in intent,
    though (as noted above) I could not find where in the repo this deferral itself was written down.
  - AC4 (`test-kit.ps1` prints `0 failed`): **Code-review-only** - I have no shell/Bash tool in this grading
    session, so I verified the new Test-Case's regexes by hand against the actual file content instead of
    running the suite. This is a limitation of my grading tool access, not a claim that the suite was run and
    passed.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [human] **Re-run `install.cmd` before `/stories` or `/design` is next invoked in a live session.**
   T7.1/T7.2 changed `global\commands\stories.md` and `global\commands\design.md`; until `install.cmd` runs,
   the copies Claude Code actually reads from `%USERPROFILE%\.claude\commands\` are stale and will NOT say
   the new pricing sentences. This is the single most important open item from this story - AC3 is not truly
   satisfied until it happens.
2. [dev] Add a short `<!-- Implemented: ... -->` note to Story S7's header in `docs\STORIES.md` (mirroring
   S1's note at `docs\STORIES.md:12-23`) recording that AC3's install.cmd re-run was deliberately deferred
   per R35(b), and that it remains outstanding until a human runs it - so the next person reading STORIES.md
   (not just this grade card) sees the gap without having to reconstruct it from the orchestrator's memory.
   T7.3's own Context (`docs\TASKS.md:428-432`) asked for exactly this "completion record" note and it does
   not appear to have landed anywhere durable.
3. [dev] When `install.cmd` is next run, re-verify `test-kit.ps1` end-to-end (`0 failed`) since this grading
   pass could only hand-check the new Test-Case's regexes against source text, not execute the suite.
