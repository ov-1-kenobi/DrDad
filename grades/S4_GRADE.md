# Story S4 - Sandbox-real-state / explicit-consent as a checkable convention : report card

**Current grade: A-**  (as of 2026-09-20, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-20        | A-    | initial implementation (T4.1, T4.2, T4.3 all present and correct; one gap in T4.2's self-test durability) |

## Assessment (this iteration)
- **Correctness vs intent:** Matches the Goal exactly - turns the R35 fix into (a) an explicit instruction
  surface for dev-agent/qa-agent and (b) a mechanical, extendable static check, rather than re-fixing
  `uninstall.ps1` (which the story correctly says needs no further code change).
- **Acceptance coverage:**
  - AC1 (met): `global\agents\dev-agent.md:83-95` and `global\agents\qa-agent.md:63-75` each carry an
    identical "## R35: never verify against the REAL machine..." block, same STOP-block tone/shape as the
    surrounding App-Control block (`dev-agent.md:79-81`), stating both rules verbatim (isolated target
    for real-state ACs; explicit consent + record-which-mode for irreversible actions).
  - AC2 (met, with one durability gap): `test-kit.ps1:653-737`, `Test-Case "state-mutating scripts confine
    real-machine writes behind a param guard"`. It is genuinely pattern-based, not line-number-pinned
    (`Get-ScriptParamNames` parses the target script's own `param()` block; `Get-GuardedRegions` finds
    `if ($<param>) {...} [else {...}]` spans via brace-depth counting; `Find-UnguardedMutations` checks 4
    danger regexes - env-var Set/RemoveEnvironmentVariable at User/Machine scope, `ollama rm`, unscoped
    `Remove-Item` on `$env:USERPROFILE`/`$HOME`, registry Set/Remove/New-ItemProperty on HKCU/HKLM - fall
    outside those regions). It passes today against the fixed `uninstall.ps1`. However, the "demonstrated
    to fail if the guard is removed" half of AC2 is NOT captured as a permanent regression check - I found
    no scratch/negative-case sub-test inside `test-kit.ps1` exercising a guard-stripped script (grepped for
    `guard-stripped`, `scratch reconstruction`, `demonstrated to fail` - no matches). Per the story text and
    the task hand-off, this was verified once, manually, during development against a "guard-stripped
    scratch reconstruction" - real but not self-checking going forward. This is exactly the failure mode
    `test-kit.ps1:153-154` itself warns about ("A static analyser that finds nothing on clean code proves
    nothing about itself... gates that pass by doing nothing are the recurring failure here") and the
    pattern the suite already uses elsewhere (`New-Sandbox` self-checks, and the newer
    `Test-Case "close-unit writes TASKS.md/STORIES.md back as LF, never CRLF"` at `test-kit.ps1:3955` which
    DOES exercise a live reconstruction inside the permanent suite). Not a story-blocking gap - AC2's
    literal wording is satisfied by the one-time demonstration - but worth closing so a future edit to the
    regex/brace logic can't silently regress undetected.
  - AC3 (met): `global\agents\grade-agent.md:77-80` (Assessment section skeleton) and `:92-104` (Rules)
    require recording verification mode (live-sandboxed vs code-review-only) + reason for any unit whose
    ACs touch real machine state, explicitly mirroring Story S1's dev-note format (quotes the exact AC1/AC2
    wording from `STORIES.md`). This is the instruction I am following in this very card (see next line).
  - AC4: full-gate pass is asserted by the commit history (T4.2/T4.3 commits) but this agent does not run
    builds/tests per its own charter - not independently re-verified here. ASCII-only confirmed directly:
    grepped all three touched files (`dev-agent.md`, `qa-agent.md`, `grade-agent.md`) plus `test-kit.ps1`'s
    new block for non-ASCII bytes - zero matches in the agent files (test-kit.ps1 not fully re-scanned
    beyond the new Test-Case region, which is also clean).
- **Design adherence:** Follows the R28 precedent the story cites (turn prose into a script gate) and
  keeps the pattern generic per R28/R29's lesson (no hardcoded line numbers) - confirmed by reading the
  `Get-ScriptParamNames`/`Get-GuardedRegions` implementation, which parses structure rather than grepping
  fixed offsets. R35 itself is a locked DESIGN.md requirement (`docs/DESIGN.md:357-361`), so this story is
  squarely in-contract, not scope creep.
- **Verification mode (per T4.3's own new rule):** Not applicable / correctly omitted. None of S4's three
  units touch real machine state themselves - they add instruction text (dev-agent.md, qa-agent.md),
  a static-analysis-only Test-Case (parses source text, executes no state-mutating code), and a
  documentation/template edit to grade-agent.md. This is the story that DEFINES the convention rather than
  triggering it, so the absence of a live-sandboxed/code-review-only note here is expected, not a gap.
- **Quality:** The new Test-Case (`test-kit.ps1:653-737`) is dense but well-commented, matches the
  surrounding file's idiom of per-Test-Case helper functions, and the R35 instruction blocks in
  `dev-agent.md`/`qa-agent.md` are near-identical (deliberately, since both agents need the same rules) -
  no drift or copy-paste divergence spotted between the two copies.
- **Hygiene:** No new dependencies; no manifest changes; ASCII convention held (verified above). Adjacent
  but NOT part of this story's three tasks: a separately-committed fix (`close-unit.ps1`'s `Save-Text`
  helper, was hardcoding CRLF against an LF-per-`.gitattributes` file, silently corrupting the on-disk copy
  of TASKS.md/STORIES.md every tick) with its own regression test at `test-kit.ps1:3955-3999`. That fix is
  exactly the kind of self-hosting bug this story's philosophy targets, and its own regression test is a
  better model of "permanent self-check" than T4.2's Test-Case currently is - see suggestion 1 below.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Close AC2's durability gap: add a small negative-case check inside (or alongside)
   `test-kit.ps1:653`'s Test-Case that builds an in-memory or scratch copy of a minimal guarded script,
   strips the `if ($Param) {...} else {...}` wrapper from one danger call, and asserts
   `Find-UnguardedMutations` actually flags it - mirroring the self-checking style already used at
   `test-kit.ps1:153-155` (`New-Sandbox`) and the newer `close-unit` LF regression test at
   `test-kit.ps1:3955`. Today the "fails when guard removed" half of AC2 is real but was a one-time manual
   demonstration, not something the suite re-checks on every run.
2. [mechanical] None needed - no dead code, no ASCII violations, no manifest drift found in the three
   touched files.
3. [human] Confirm whether AC2's wording ("demonstrated to fail") was intended to require a permanent
   regression test or just a one-time dev-time proof; if the former, promote suggestion 1 from optional
   polish to a blocking follow-up task before treating S4 as fully closed against the letter of its own AC.
