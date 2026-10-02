# Story S24 - The local-model probe SHOWS the unrecognized_model warning instead of discarding it : report card

**Current grade: B+**  (as of 2026-10-02, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-02        | B+    | initial implementation (T24.1-T24.3, commits b3a6f1a..2a2fbe5)          |

## Assessment (this iteration)
- Correctness: matches the Goal. harness-versions.ps1:123 now runs the `claude` probe with `2> $errFile`
  (was `2>$null`), harness-versions.ps1:125-126 reads the captured stderr, and harness-versions.ps1:127
  prints exactly `[harness] local model ${model}: WARN unrecognized_model (Claude Code assumes a 200000
  context window; Ollama serves unknown)` BEFORE the outcome checks at harness-versions.ps1:128-136, which
  are unchanged - so the WARN never turns into a FAIL (C4a) and other stderr content changes nothing.
  `${model}` is braced correctly. The function-scoped `$ErrorActionPreference = 'Continue'`
  (harness-versions.ps1:119) protects against PS 5.1 NativeCommandError under install.ps1's `Stop`.
  The env-only reachability seam is at harness-versions.ps1:107-115 (`up`/`down` make no request; unset
  falls back to the original Invoke-WebRequest); the SKIP reason text at harness-versions.ps1:116 is
  byte-identical. `Invoke-PostUpdateSmoke` sets `$skipNote` at harness-versions.ps1:151 and
  harness-versions.ps1:168, and harness-versions.ps1:180-181 prints the qualified line on a skip and the
  bare line otherwise. The temp file is removed in `finally` (harness-versions.ps1:141).
- Acceptance: AC1/AC2 covered by test case "S24 AC1/AC2: the local-model probe PRINTS the unrecognized_model
  WARN and stays PASS" (test-kit.ps1:1809-1818): exact WARN text via `.Contains()` + `RESULT PASS`, and the
  no-stderr run asserts PASS with no WARN. AC3 covered by "S24 AC3: Ollama unreachable -> local-model SKIP,
  and the final smoke line names the skip and its reason" (test-kit.ps1:1820-1828): SKIP result, the
  qualified final line, no bare `smoke check passed\s*$` line, and copilot-cli keeps the bare line.
  AC4 (`0 failed`): NOT run by me (assessor does not run tests); commit 2a2fbe5 was closed by close-unit,
  which gates on the suite. Gaps: (a) Behavior bullet 2 ("any other stderr content: behaviour unchanged")
  has no case - no stub writes non-warning stderr; (b) T24.2's acceptance "with DAD_SMOKE_LOCALMODEL=pass
  claude-code prints the bare line" is not automated - the helper always clears DAD_SMOKE_LOCALMODEL
  (test-kit.ps1:1799). (c) T24.3's mutation check (re-adding `2>$null` fails AC1) is a manual step with no
  recorded evidence; logically it would fail, since the WARN is only reachable via $errText.
- Design: within scope - only harness-versions.ps1 and test-kit.ps1 changed; install.ps1:116 (sole caller)
  untouched; models.json `numCtx` deliberately not read (`unknown` per C4a OPEN-4(b)). No scope creep.
- Quality: idiomatic and small. Nits: the comment reflow at harness-versions.ps1:86 jams two sentences onto
  one ~150-char line, unlike the wrapped block around it; `$errFile` is not initialised before the `try`
  (harness-versions.ps1:118-120), so when dot-sourced into install.ps1 the `finally` guard at
  harness-versions.ps1:141 could act on a stale caller-scope `$errFile` if GetTempFileName ever threw.
  Test helper Invoke-S24Probe (test-kit.ps1:1777-1807) is clean: env saved/restored, sandbox removed in
  finally, quoting of $kit/$fixture escaped. The copilot-cli body passes `-Package '@anthropic-ai/claude-code'`
  (test-kit.ps1:1826) - harmless (only used in FAIL text) but misleading.
- Hygiene: ASCII kept in the touched lines; no new deps. docs/STORIES.md S24 is marked DONE but its AC1-AC4
  checkboxes are still `[ ]`.
- Verification mode (the probe sets ANTHROPIC_BASE_URL/ANTHROPIC_AUTH_TOKEN and invokes `claude` - real
  machine state):
  - AC1/AC2: Behaviorally verified by the suite (per close-unit on 2a2fbe5), live-sandboxed: stub
    `claude.cmd` first on a CHILD process PATH, DAD_SMOKE_OLLAMA forced `up` (no network), env restored in
    finally (test-kit.ps1:1797-1805). Real claude/npm/settings never invoked. Not re-run by this assessor.
  - AC3: same sandbox, DAD_SMOKE_OLLAMA=`down`, DAD_SMOKE_GATES=`pass` - no gates-smoke child, no request.
  - The unset-seam path (real Invoke-WebRequest to localhost:11434 followed by the real `claude`) is
    code-review-only, by design, to avoid driving the real Claude Code against the real Ollama in CI.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Add a case (or extend test-kit.ps1:1809) where the stub writes NON-warning stderr (e.g. `some
   other notice`) and assert `RESULT PASS` and no `WARN unrecognized_model` - S24 Behavior bullet 2 is
   currently untested.
2. [dev] Automate T24.2's remaining acceptance: let Invoke-S24Probe take an optional DAD_SMOKE_LOCALMODEL
   value and assert `claude-code smoke check passed\s*$` when it is `pass` (the PASS-keeps-bare-line half of
   Behavior bullet 3 for claude-code itself).
3. [dev] Initialise `$errFile = $null` before the `try` in Test-LocalModelResolves (harness-versions.ps1:117)
   so the `finally` at harness-versions.ps1:141 can never remove a caller-scope file of the same name.
4. [mechanical] Re-wrap the comment at harness-versions.ps1:86 to the ~105-col width of lines 81-88;
   change `-Package` in the copilot-cli body at test-kit.ps1:1826 to the Copilot CLI package name the kit already uses for copilot-cli (check install.ps1),
   for readability.
5. [mechanical] Tick the S24 AC1-AC4 checkboxes in docs/STORIES.md (story is DONE, boxes still empty).
6. [human] The `<ctx>` source is still `unknown` (S24 Dev notes QUESTION; C4a OPEN-4(b)). Decide in
   `/design` whether to pin it (e.g. query Ollama `/api/show` for the served num_ctx) - until then the WARN
   cannot state the actual 40960 hazard number.
