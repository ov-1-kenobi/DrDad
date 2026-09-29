# Story S8 - dad gates-smoke - prove the gates actually fire : report card

**Current grade: A-**  (as of 2026-09-28, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-28        | A-    | initial grading after T8.1-T8.4 all closed |

## Assessment (this iteration)

- **Correctness vs intent:** Matches the Goal/Behavior exactly. `dad-gates-smoke.ps1` (D:\projects\DrDad\dad-gates-smoke.ps1)
  provokes all three named gates for real, against throwaway git-initialized fixtures in `$env:TEMP`, never
  the real `-ProjectDir` target (correctly called out at :118-119 and :185-186, citing R35 by name). Loop
  guard: forces up to 4 identical `dad-loopguard.ps1` hook calls with a scoped session id and checks for
  exit 2 (:48-93). Ratchet/close-unit: builds a fixture, does a clean first close via `close-unit.ps1`,
  then shrinks `[Fact]` markers 10->1 and re-closes, asserting refusal + `SHRANK` in output (:95-170).
  Dad-guard Stop: builds a fixture with `docs\DESIGN.md`, commits a clean baseline, adds one untracked
  `.cs` file, then runs `dad-guard.ps1 -Check` and asserts exit 1 (:172-224). This is genuine provocation,
  not a mocked check.

- **Acceptance coverage:**
  - AC1 (loop guard blocks 4th call, reported intercepted): met, :48-93, and exercised by
    `test-kit.ps1:1895-1911` ("dad-gates-smoke intercepts all three real gates") which asserts the literal
    string `[gates-smoke] loop-guard: INTERCEPTED` in output.
  - AC2 (shrunk test/story count -> ratchet refusal reported intercepted): met, :95-170. Dev notes
    correctly disambiguate the WARN-only `[ratchet]` C1d finding from the actually-blocking `ratchet.ps1`
    (R28) mechanism invoked by `close-unit.ps1` - this is a real design-clarification catch, not scope
    creep (T8.3's own Do-notes in docs/TASKS.md:577-587 document the same finding). Verified same test
    case asserts `ratchet-close-refusal: INTERCEPTED`.
  - AC3 (uncommitted+unstamped code blocked at Stop): met, :172-224, `dad-guard.ps1 -Check` exit-1 check
    matches `dad-guard.ps1:18`'s own documented `-Check` contract. Verified by the same aggregate test case.
  - AC4 (exit 0 only if every provoked gate intercepted; non-zero + naming on any silent pass): met,
    :251-274 - `$silentFails`/`$intercepted`/`$skipped` computed from the result set, exit 1 with the
    failing gate name(s) joined into the message (:261-264), exit 0 only when zero silent-fails and not
    all-skipped (:266-273). Verified by `test-kit.ps1:1907,1909` (asserts no `SILENT-FAIL` string, exit 0).
  - AC5 (SKIP never fabricated as pass): met structurally - each `Test-*Gate` function returns SKIP with a
    stated reason on precondition failure (missing sibling script, no git on PATH, or a broken fixture
    baseline: :53, :111, :115, :154, :178, :182) and the aggregate logic (:266-270) treats an all-SKIP run
    as a FAIL, never a PASS. `test-kit.ps1:1871-1893` (T8.1's original skeleton case) still asserts the
    parse/ASCII/usage/loud-failure contract holds regardless of which gates are stubbed vs real, and the
    T8.4 case (:1895-1911) asserts zero SKIP when run against the kit's own working gates - together these
    cover both the "some skip" and "none skip" paths, though there is no test that forces an INDIVIDUAL
    gate into a genuine SKIP against real, present tooling (e.g. by hiding git from PATH) to prove the
    per-skip branch text itself is reachable in practice; this is a minor coverage gap, not a design flaw.

- **Design adherence:** Report/exit-code contract exactly matches T8.1's spec (docs/TASKS.md:473-513): one
  line per gate with Result + optional Reason (dad-gates-smoke.ps1:41-46, :240-241), ordered gate list
  matching S8's Behavior order (loop-guard, ratchet-close-refusal, dad-guard-stop: :228-232). `CmdletBinding()`
  + `-ProjectDir` existence guard exiting 2 (:26-38) matches the stated convention and is verified by
  `test-kit.ps1:1889-1892`. `.cmd` wrapper (D:\projects\DrDad\dad-gates-smoke.cmd) is the exact one-line
  pattern used elsewhere. `dad.cmd:81` advertises `dad gates-smoke` in the same 4-space-indented style as
  neighboring entries, matching T8.1 Do-step 6 exactly.

- **Quality:** Clean, well-commented PowerShell that reuses proven fixture shapes from existing
  `test-kit.ps1` Test-Cases rather than inventing new ones (explicitly cited at :61-62, :120-121, :186-188)
  - exactly the "reuse, don't invent" discipline the tasks called for. Consistent try/finally cleanup of
  temp fixtures and `Set-Location`/`$ErrorActionPreference` restoration in both fixture-based gates
  (:137-149, :197-209). Session-scoped loop-guard id (`gates-smoke-$PID-$(Get-Random)`, :58) avoids
  polluting a real session's streak state, then resets state before and after (:59, :87) - good hygiene.
  One small wart: `Test-LoopGuardGate` defines a nested nested-function `Invoke-LoopGuard` and captures
  `$i` from the enclosing `for` loop for its INTERCEPTED reason string (:90, "blocked by attempt $i") -
  this works but a reader has to trace scope leakage across the loop/finally boundary to see why it's
  valid; a one-line comment would help. No dead code found; no obvious copy-paste bugs.

- **Hygiene:** `dad-gates-smoke.ps1` file itself confirmed ASCII (test-kit.ps1:1880-1881 asserts this and
  is presumably green per the story's DONE status) and structured with `` ` `` for backtick literal usage
  consistent with the rest of the kit's PowerShell. `dad.cmd:81` entry is in sync with the shipped command.
  Two new Test-Cases exist in test-kit.ps1 (:1871, :1895) as promised by T8.1 and T8.4's Do-steps.

- **Flagged, NOT scored against S8** (per the prompt's instruction - both are real, live gaps the human
  should track, neither is S8's code fault):
  1. **CRLF drift on close.** During this story's build, `docs/TASKS.md`, `docs/API-SURFACE.md`, and
     `docs/STORIES.md` were observed drifting back to CRLF after every `close-unit.ps1` run, requiring
     manual re-normalization; isolated `git add`/`commit` testing did not reproduce it, so root cause is
     still unknown. This is an environmental/tooling gap unrelated to `dad-gates-smoke.ps1` itself (which
     is correctly ASCII/LF per test-kit.ps1:1880-1881), but it is a live process risk for every future
     close and should be tracked, not silently absorbed as "just re-normalize by hand."
  2. **`$haveGit` ordering bug in test-kit.ps1.** Dev-agent found during T8.3 that `$haveGit` is assigned
     near test-kit.ps1 line ~3899, but roughly 17 `Test-Case` blocks earlier in the file guard on
     `if (-not $haveGit) { return }` before that assignment ever runs - meaning those ~17 cases silently
     false-pass (return early, reporting nothing meaningfully executed) rather than actually skipping for
     a real, stated reason. This is a real, unfixed bug in the test harness itself, independent of S8's
     own two new Test-Cases (which do not rely on `$haveGit`).

- **Verification mode:** S8's ACs exercise real machine state (temp-dir git fixtures, real hook scripts,
  real exit codes) but always against throwaway, self-constructed fixtures under `$env:TEMP`, never a real
  project - this was verified by code review of `dad-gates-smoke.ps1` (:118-119, :185-186, explicit R35
  citations) plus the corresponding `test-kit.ps1` assertions (:1895-1911) which are part of the kit's own
  gate (`test-kit.ps1`, "0 failed"). This grading pass was code-review-only: I did not re-run
  `test-kit.ps1` or `dad-gates-smoke.ps1` myself in this session (no shell access in this role); the DONE
  status on T8.1-T8.4 in docs/TASKS.md and the presence of both new Test-Cases matching the described
  contract is what I verified. If the orchestrator has not itself re-run `test-kit.ps1` since T8.4 closed,
  that is the one live-execution gap left to confirm, not a code-quality gap.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Add a `test-kit.ps1` case (or extend the T8.1 skeleton case) that forces at least one gate into a
   genuine SKIP against otherwise-working tooling (e.g. temporarily hide `git` from PATH or point
   `-ProjectDir`/sibling resolution at a dir missing `ratchet.ps1`) to prove the per-gate SKIP branch text
   (dad-gates-smoke.ps1:111, :115, :154, :178, :182) is reachable and correctly formatted, not just that
   the aggregate "all-SKIP -> FAIL" logic works.
2. [dev] Schedule a fix for the `$haveGit` ordering bug in `test-kit.ps1` (~17 `Test-Case` blocks before
   its assignment near line ~3899 silently false-pass instead of skipping for a stated reason) - found by
   dev-agent during T8.3, unrelated to S8's own two new cases but a real gap in the harness those cases
   now sit inside.
3. [human] Decide how to handle the CRLF-drift-after-close-unit issue on docs/TASKS.md, docs/API-SURFACE.md,
   docs/STORIES.md - root cause not found by isolated git add/commit testing; currently worked around by
   manual re-normalization after every close, which does not scale and risks silently reverting to CRLF
   again on a future close nobody remembers to check.
4. [mechanical] Add a one-line comment at dad-gates-smoke.ps1:90 noting that `$i` is intentionally read
   from the enclosing `for` loop's final value after `break` to name which attempt blocked - a minor
   readability nit, safe for hygiene-agent to add without changing behavior.
