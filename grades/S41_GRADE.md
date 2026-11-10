# Story S41 - Refactor - tests are checked at every task close, and the two test-writing agents stop duplicating each other : report card

**Current grade: B**  (as of 2026-11-10, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-11-10        | B     | initial implementation (commits daf7c49, a8f0894); graded by code review only |

## Assessment (this iteration)
How this story was closed: implemented directly from a review's issue list and marked DONE by hand at the
owner's request, NOT through close-unit. There is no close evidence file (`grades/S41_EVIDENCE.md` does not
exist). I did not see tests run and cannot run them. The last full suite run reported to me on this branch
was 309 passed, 2 failed; the two were said to be fixed and re-checked one at a time, and a final full run
is still pending. So the suite is NOT known to be green, and this grade rests on reading the code and the
test bodies only. That, plus the defects below, is why the grade is B and not higher.

- Correctness: the Goal is implemented as written.
  - `close-unit.ps1:646` runs the block only when the close is not a story roll-up; `close-unit.ps1:647`
    reads the optional line with `Get-ClaudeCommand 'Fast test'`; a non-zero exit refuses the close at
    `close-unit.ps1:652` (gate log at `close-unit.ps1:658`, exit at `close-unit.ps1:659`); zero tests
    refuses at `close-unit.ps1:661`. Both refusals exit before anything is ticked or committed.
  - No line means no change: `close-unit.ps1:648` skips when the command is empty, and the scaffold's
    unfilled placeholder is treated as empty by `close-unit.ps1:75` (a value starting with `<`).
  - A story close runs the full suite instead: `close-unit.ps1:676` to `close-unit.ps1:677`. The last
    task of a story sets `$predictedStory` (`close-unit.ps1:409`), so that close gets the full `Test:`
    command and not the subset.
  - "Zero" covers the real dotnet case: `close-unit.ps1:199` maps "no test matches" to a count of 0.
  - One softness: a fast test that exits 0 and prints NO count is accepted (`close-unit.ps1:669`), while
    the story path refuses the same situation (`close-unit.ps1:699`). The story's wording ("failure or zero
    tests refuses") does not cover it either way; see suggestion 2.
  - The whole block sits inside `if (-not $SkipVerify)` (`close-unit.ps1:558`), so `-SkipVerify` skips
    fast tests too. Consistent with the build check; noted, not a defect.
- Acceptance:
  - AC1 covered by `0.60.0 #12: CLAUDE.md's optional 'Fast test:' runs on EVERY task close and blocks it; no line = unchanged; a story close runs the full suite instead`
    at `test-kit.ps1:9207`. It asserts: a failing fast test exits 1 and leaves T1.1 unticked
    (`test-kit.ps1:9215`, `test-kit.ps1:9216`); the refusal is logged once (`test-kit.ps1:9218`); a
    passing one closes (`test-kit.ps1:9221`); the story close runs 3 tests and prints no "fast tests"
    (`test-kit.ps1:9224`); a filter that selects nothing is refused (`test-kit.ps1:9230`); a project with
    no line is untouched (`test-kit.ps1:9237`); the template placeholder is an `<optional` placeholder
    (`test-kit.ps1:9242`). Every clause of AC1 has an assertion. Gap: the no-count path
    (`close-unit.ps1:669`) and the upgrade hint (`upgrade-project.ps1:420`) have no assertion.
  - AC2 covered by `0.61.0 #13: qa-agent lists existing tests first and adds only uncovered ones; both agents share one fixtures folder`
    at `test-kit.ps1:9431`. It checks the list-first wording (`test-kit.ps1:9434`), the uncovered-only
    limit (`test-kit.ps1:9435`), the fixtures folder in both prompts (`test-kit.ps1:9437`) and the order
    (`test-kit.ps1:9439`). The prompts match: `global/agents/qa-agent.md:18` (list first) precedes
    `global/agents/qa-agent.md:29` (write tests); fixtures rule at `global/agents/qa-agent.md:25` and
    `global/agents/dev-agent.md:24`. This is a text-presence test by design (option A, prompts only, the
    owner's choice per the story's Dev notes); it proves the rule is stated, not that agents obey it.
- Design: every file in the story's Data / interfaces carries its change and nothing outside the list was
  needed: `templates/generic/CLAUDE.md:55` (placeholder line), `templates/dotnet/PROFILE.md:26` (the
  dotnet example), `upgrade-project.ps1:420` (prints a hint, never injects the line - correct, since
  Build / test is the project's own section), `global/commands/build.md:140` (doc mention). No pinned
  contract is touched. No scope creep found. The story header still reads "R: pending, see T46.5", so
  requirement traceability is open by the story's own admission.
- Quality: the close-unit block is readable, mirrors the story-test block beside it, and logs each
  refusal. One real defect in a prompt: `global/agents/dev-agent.md:27` ends the new fixtures bullet and
  starts the next bullet ON THE SAME LINE ("...they prove.- **LOOK UP EVERY SIGNATURE..."), so the
  signature-lookup rule no longer renders as its own bullet. The edit for this story introduced the join
  and no test catches it.
- Hygiene: `templates/dotnet/PROFILE.md:26` writes the label as "Fast test (optional - ...):", which the
  parser at `close-unit.ps1:69` would NOT match if a model copied the bullet verbatim into CLAUDE.md; the
  text at `templates/dotnet/PROFILE.md:28` does tell the reader the right form, so the risk is small.
  ASCII and PS 5.1 conventions look respected in the lines read. Not checked: `new-project.ps1`, the
  fixture helper `New-PfFixture -FastTest`, and whether the installed copy has been refreshed.
- Verification mode: both ACs run in suite sandboxes (`New-Sandbox`, `test-kit.ps1:9209`) and touch no
  real machine state. AC1 and AC2: code-review verified 2026-11-10, not live-run by me - no close evidence
  file exists and this agent has no shell.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [mechanical] `global/agents/dev-agent.md:27` - put the line break back between "...they prove." and
   "- **LOOK UP EVERY SIGNATURE", so the signature rule is its own bullet again. Add one assertion to the
   `0.61.0 #13` case (`test-kit.ps1:9431`) that no line in either prompt contains ".- **".
2. [dev] `close-unit.ps1:669` - decide and test the no-count case. Either refuse it as the story path does
   at `close-unit.ps1:699`, or keep it lenient and say why in the comment; then add an assertion for it
   to the case at `test-kit.ps1:9207`. Today a fast-test command that prints nothing countable passes on
   exit code alone, which is the "green run of nothing" the rest of this file refuses.
3. [human] The story was marked DONE by hand with no close evidence file and no confirmed green full
   run. Run the full suite once and record the result before treating S41 (and this grade) as settled;
   whether to close it retroactively through close-unit is your call.
4. [dev] Add an assertion that `upgrade-project.ps1:420` prints the Fast test hint when a project has a
   `Test:` line and no `Fast test:` line, and stays quiet when it has one - the branch is untested.
5. [mechanical] `templates/dotnet/PROFILE.md:26` - write the example as a literal
   "- Fast test: `dotnet test --filter "Category=SourceScan"`" line, with the explanation on the lines
   after it, so a verbatim copy parses at `close-unit.ps1:69`.
