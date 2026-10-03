# Story S24 - The local-model probe SHOWS the unrecognized_model warning instead of discarding it : report card

**Current grade: A-**  (as of 2026-10-02, iteration 2)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-02        | B+    | initial implementation (T24.1-T24.3, commits b3a6f1a..2a2fbe5)          |
| 2    | 2026-10-02        | A-    | T24.4 (2deb838): Behavior 2 + PASS bare-line cases, `$errFile = $null` + its test; iter-1 sugg. 1-4 applied |

## Assessment (this iteration)
- Correctness: matches the Goal. harness-versions.ps1:124 runs the `claude` probe with `2> $errFile`
  (was `2>$null`), harness-versions.ps1:126-127 reads the captured stderr, and harness-versions.ps1:128
  prints exactly `[harness] local model ${model}: WARN unrecognized_model (Claude Code assumes a 200000
  context window; Ollama serves unknown)` BEFORE the outcome checks at harness-versions.ps1:129-137, which
  are unchanged - so the WARN never turns into a FAIL (C4a) and other stderr content changes nothing.
  `${model}` is braced correctly. The function-scoped `$ErrorActionPreference = 'Continue'`
  (harness-versions.ps1:120) protects against PS 5.1 NativeCommandError under install.ps1's `Stop`.
  The env-only reachability seam is at harness-versions.ps1:106-115 (`up`/`down` make no request; unset
  falls back to the original Invoke-WebRequest at harness-versions.ps1:112); the SKIP reason text at
  harness-versions.ps1:116 is byte-identical. NEW in T24.4: `$errFile = $null` at harness-versions.ps1:118,
  directly before the `try` at harness-versions.ps1:119, so the `finally` guard at harness-versions.ps1:142
  can only ever remove the function's own temp file (PowerShell dynamic scoping no longer leaks a caller's
  `$errFile` into it). `Invoke-PostUpdateSmoke` initialises `$skipNote` at harness-versions.ps1:152, sets it
  in the SKIP branch at harness-versions.ps1:169, and harness-versions.ps1:181-182 prints the qualified
  line on a skip and the bare line otherwise; `return $true` unchanged (harness-versions.ps1:183).
- Acceptance: covered.
  - AC1/AC2: "S24 AC1/AC2: the local-model probe PRINTS the unrecognized_model WARN and stays PASS"
    (test-kit.ps1:1810-1819): exact WARN text via `.Contains()` + `RESULT PASS`; the no-stderr run asserts
    PASS with no WARN.
  - AC3: "S24 AC3: Ollama unreachable -> local-model SKIP, and the final smoke line names the skip and its
    reason" (test-kit.ps1:1821-1829): SKIP result, the qualified final line, no bare
    `smoke check passed\s*$` line, and copilot-cli keeps the bare line.
  - Behavior bullet 2 (iter-1 gap a, now closed): "S24 Behavior 2: ordinary stderr from claude is not a
    WARN and the probe stays PASS" (test-kit.ps1:1831-1835) - stub writes `some other notice`, asserts
    `RESULT PASS` and no `WARN unrecognized_model`.
  - Behavior bullet 3 PASS half / T24.2 acceptance (iter-1 gap b, now closed): "S24 Behavior 3: a PASSing
    local-model check keeps the bare claude-code smoke line" (test-kit.ps1:1837-1841), via the new optional
    `$LocalModel` parameter of Invoke-S24Probe (test-kit.ps1:1778, applied at test-kit.ps1:1800; 3-arg
    calls still clear DAD_SMOKE_LOCALMODEL). Note it drives the bare branch through the `pass` short-circuit
    (harness-versions.ps1:95), not through a real stub-`claude` PASS - acceptable, it matches the T24.2
    acceptance wording in docs/TASKS.md exactly.
  - errFile scoping: "S24 cleanup: the probe's finally never deletes a caller-scope errFile"
    (test-kit.ps1:1843-1849) forces GetTempFileName() to throw (TMP/TEMP at a missing dir), asserts
    `RESULT FAIL` (setup reached the path) and `KEPT True`. This is a genuinely mutation-sensitive design:
    without harness-versions.ps1:118 the `finally` would read the driver's `$errFile` and delete keep.txt.
  - AC4 (`0 failed`): NOT run by me (assessor does not run tests); 2deb838 was closed by close-unit, which
    gates on the full suite (CLAUDE.md Test bullet) and refuses a non-zero or zero-test run.
  - Remaining evidence gap: T24.3's and T24.4's mutation checks (docs/TASKS.md T24.4 Acceptance items 1-3)
    are manual steps; I found no recorded evidence they were performed. Logically each would fail as
    described (WARN only reachable via `$errText` match; bare line only when `$skipNote` empty; KEPT
    depends on line 118).
- Design: within scope - only harness-versions.ps1 and test-kit.ps1 changed across T24.1-T24.4;
  install.ps1:116 (sole caller) untouched; models.json `numCtx` deliberately not read (`unknown` per C4a
  OPEN-4(b)). T24.4 added exactly the one line its Do step 1 allowed in harness-versions.ps1. No scope creep.
- Quality: idiomatic and small. Iter-1 nits resolved: the comment at harness-versions.ps1:85-88 is now
  wrapped to the width of the surrounding block; the copilot-cli body at test-kit.ps1:1827 now passes
  `-Package '@github/copilot'` instead of the misleading claude-code package. Test helper Invoke-S24Probe
  (test-kit.ps1:1778-1808) stays clean: env saved/restored for all four names, sandbox removed in finally,
  `$kit`/`$fixture` single-quote escaping correct, header comment documents `$LocalModel`
  (test-kit.ps1:1777). Minor: the cleanup case body at test-kit.ps1:1846 is one ~330-char line; readable
  enough given the comment above it at test-kit.ps1:1844-1845.
- Hygiene: ASCII kept in the touched lines; no new deps or manifests touched. docs/STORIES.md S24 is DONE
  with AC1-AC3 ticked; AC4 is still `[ ]` (being ticked separately by scribe-agent per the orchestrator).
- Verification mode (the probe sets ANTHROPIC_BASE_URL/ANTHROPIC_AUTH_TOKEN and invokes `claude` - real
  machine state):
  - AC1/AC2 and Behavior 2: Behaviorally verified by the suite (per close-unit on 2a2fbe5 / 2deb838),
    live-sandboxed: stub `claude.cmd` first on a CHILD process PATH, DAD_SMOKE_OLLAMA forced `up` (no
    network), env restored in finally (test-kit.ps1:1798-1806). Real claude/npm/settings never invoked.
    Not re-run by this assessor.
  - AC3 and Behavior 3: same sandbox, DAD_SMOKE_OLLAMA=`down` (AC3) or DAD_SMOKE_LOCALMODEL=`pass`
    (Behavior 3), DAD_SMOKE_GATES=`pass` - no gates-smoke child, no request.
  - errFile cleanup case: TMP/TEMP are redirected only inside the child powershell process
    (test-kit.ps1:1846), so the real temp dir is untouched.
  - The unset-seam path (real Invoke-WebRequest to localhost:11434 followed by the real `claude`) is
    code-review-only, by design, to avoid driving the real Claude Code against the real Ollama in CI.

## Suggestions (prioritized; tag each so the team knows who acts)
1. APPLIED (T24.4) - was [dev]: non-warning stderr case -> "S24 Behavior 2: ordinary stderr from claude is
   not a WARN and the probe stays PASS" (test-kit.ps1:1831).
2. APPLIED (T24.4) - was [dev]: automate T24.2's DAD_SMOKE_LOCALMODEL=pass bare-line acceptance ->
   "S24 Behavior 3: a PASSing local-model check keeps the bare claude-code smoke line" (test-kit.ps1:1837).
3. APPLIED (T24.4) - was [dev]: `$errFile = $null` before the `try` (harness-versions.ps1:118), plus a
   regression case (test-kit.ps1:1843).
4. APPLIED - was [mechanical]: comment re-wrapped (harness-versions.ps1:85-88); copilot-cli `-Package`
   now `@github/copilot` (test-kit.ps1:1827).
5. PARTLY APPLIED - was [mechanical]: AC1-AC3 boxes ticked in docs/STORIES.md; AC4 still `[ ]` - being
   handled by scribe-agent (no action from hygiene-agent).
6. [human] The `<ctx>` source is still `unknown` (S24 Dev notes QUESTION; C4a OPEN-4(b); docs/TASKS.md
   open-questions note "[design] S24 `<ctx>` source"). Decide in `/design` whether to pin it (e.g. query
   Ollama `/api/show` for the served num_ctx) - until then the WARN cannot state the actual 40960 hazard.
7. [human] Mutation checks for T24.3/T24.4 (restore `2>$null`; WARN on any stderr; force `$skipNote`;
   drop harness-versions.ps1:118) have no recorded evidence. Decide whether close-unit's green suite is
   sufficient or whether dev-agent should note mutation results in the commit message going forward.
8. [mechanical] Optional: split the long body string at test-kit.ps1:1846 into a `$body = @(...) -join
   '; '` array, matching the `$body` variable style at test-kit.ps1:1811, for readability.
