# Story S12 - GitHub Copilot CLI as a second harness (opt-in install target) : report card

**Current grade: A-**  (as of 2026-09-29, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-29        | A-    | initial implementation (commit 64188cc, branch dogfood/copilot-pilot; delivered as a research pilot ahead of the story card) |

## Assessment (this iteration)

- **Correctness vs intent:** Matches the Goal exactly, including its hardest clause ("WITHOUT forking either
  guard script"). `dad-guard-copilot.ps1:30-37,41,52-77` runs the UNMODIFIED `dad-guard.ps1` on the verbatim
  stdin payload (temp file, `cmd /c ... < file`) and re-emits its verdict with `exit 0`; all decision logic
  (project detection, git diff, `stop_hook_active` release, fail-open) stays in `dad-guard.ps1` - I confirmed
  `dad-guard.ps1:48-57` still emits the compressed single-line `{"decision":"block",...}` + `exit 2` that the
  adapter's regex at `dad-guard-copilot.ps1:64` is written against, so the two agree. `copilot-hooks.json:12-19`
  wires `dad-loopguard.ps1` BARE on `PreToolUse` (C2c: Copilot honors exit 2 there), which is the correct
  asymmetry rather than a reflex "adapter everywhere". Grep across the repo for `copilot` returns only the 9
  expected files - `dad-guard.ps1` and `dad-loopguard.ps1` are genuinely untouched by this work.

- **Acceptance coverage:** AC1-AC5 covered; AC6 deferred and disclosed. Per criterion:
  - **AC1 - covered, with one weak assertion.** `test-kit.ps1:1338-1380` checks `version:1`
    (`:1344`), PascalCase-only events (`:1350-1352`, `-cmatch '^[A-Z]'` catches a camelCase duplicate that
    would double-fire the loop guard), Stop -> `dad-guard-copilot` (`:1358`), PreToolUse -> `dad-loopguard`
    (`:1360`), `bash`+`powershell`+`type:command` on every entry (`:1362-1368`), no BOM (`:1342`), and the
    dev-path placeholder present (`:1372`). The template `copilot-hooks.json` satisfies every one of these and
    is byte-for-byte the C2 worked example (`docs/DESIGN.md:682-700`). **Weak spot:** the install-side half of
    AC1 is asserted by GREPPING install.ps1's source (`test-kit.ps1:1375-1376`,
    `'\$h\.bash\s*=\s*\$h\.bash\.Replace'`) - the exact implementation-detail pinning that `uninstall.ps1:17-19`
    records the kit learning NOT to do ("generalising the removal ... broke the test while improving the code.
    A gate that cannot be run is prose"). The placeholder rewrite itself (`install.ps1:286-298`) is never
    executed by a test; it was executed only in the manual E2E replay.
  - **AC2 - covered, genuinely behavioral.** `test-kit.ps1:1382-1428` runs the REAL adapter against four stub
    guards in a sandbox and asserts the outcomes, not the source: block -> exit 0 + `"decision":"block"` +
    reason preserved (`:1404-1406`), allow -> exit 0 and NO `"decision"` on stdout (`:1412-1413`, which is the
    assertion that would catch a "blocks every stop" regression), block-with-no-JSON -> synthesized decision
    (`:1420`, matching `dad-guard-copilot.ps1:71-74`), guard missing -> fails open (`:1425-1426`, matching
    `dad-guard-copilot.ps1:41`). This is the best test in the set.
  - **AC3 - covered and sandboxed.** `test-kit.ps1:1430-1447` runs the real `uninstall.ps1` with `-ClaudeDir`
    AND `-CopilotDir` pointed at temp dirs, asserts our `dad.json` is gone (`:1441`) and that a foreign
    `{"version":1,"hooks":{}}` survives (`:1445`) - the guard-reference check at `uninstall.ps1:92` is what
    makes that second assertion pass. `-CopilotDir` (`uninstall.ps1:21-27`) exists only so this is testable
    without touching the real machine, matching the `-ClaudeDir` precedent.
  - **AC4 - covered.** `test-kit.ps1:1449-1477` extracts `$CopilotMeasuredVersion` from `install.ps1:32`,
    extracts the stamp from C2's `Status: MEASURED ... 1.0.89` line (`docs/DESIGN.md:571`), asserts equality
    (`:1465`), asserts `dad-doctor.ps1` READS the constant and does not quote its own copy (`:1469-1470` -
    verified true at `dad-doctor.ps1:471-478`), and asserts NEITHER guard self-checks the version at runtime
    (`:1473-1476`), which is C2f's fail-open-at-runtime half. The doc-vs-code drift the whole contract is
    about is genuinely closed against itself.
  - **AC5 - live end-to-end, and the evidence is the right KIND of evidence.** As reported: the Stop block was
    confirmed by the model attempting `dad-guard.ps1 -Ack`, a remediation string that appears ONLY inside
    dad-guard's block message, and the loop-guard denial by counting 3 side-effect lines for 4 attempts.
    Both are third-party observations, not agent self-report - exactly the standard R37(c)/C2d demand.
  - **AC6 - NOT met, DEFERRED, and honestly disclosed.** `docs/STORIES.md:515-519` states the deferral, its
    reason (R35(b); npm global install, USER PATH, `%USERPROFILE%`), what was substituted (the `test-kit.ps1`
    case plus a faithful replay of the JSON transformation), the S7 precedent, and the action left for the
    human. **This is a clear improvement on S7**, whose AC3 deferral was real but left no durable in-repo
    trace (see `grades/S7_GRADE.md:36-43`, suggestion 2). The substitute verification is honest about being a
    substitute - it does not claim step 9 ran. It IS still the thinnest point of the story: the one code path
    no automated test executes is the one that writes a file to a real user profile.

- **Design adherence:** Excellent, and traceable point by point. Every element of `copilot-hooks.json` maps to
  a named C2 sub-decision: user-level only (C2a - `install.ps1:279-284` writes `.copilot\hooks\dad.json` and
  never `.github/hooks/`), `version:1` + `bash`/`powershell` keys and PascalCase-once (C2b), adapter on Stop
  only (C2c), teardown symmetry (R37e/C2 invariant iv - `uninstall.ps1:83-103`), version drift loud at setup
  only (C2f - `install.ps1:264-277` warns and installs anyway; `dad-doctor.ps1:496-505` warns; neither guard
  self-checks). C2 invariant (ii) - no fork - holds. C2f's "deliberately NOT done yet: a `harnesses.json`
  manifest" (`docs/DESIGN.md:673-675`) is a correct, argued exception to CLAUDE.md's "never hard-code a list
  in a script" convention, not a silent violation, and it names the trigger for revisiting it. No scope creep:
  the file list matches the story's Data/interfaces line exactly.
  **One divergence found, in the DOC not the code:** C2's line citations into `install.ps1` are stale by
  ~20 lines - C2a says the file write is at `install.ps1:262-265` (that range is actually the "copilot not on
  PATH" warn), the worked example says the placeholder rewrite is at `install.ps1:266-284` (actually 286-298),
  and invariant (v) cites `install.ps1:293` for the restart notice (actually 313). The `test-kit.ps1:1338/1382/1430`
  citations at `docs/DESIGN.md:577-579` and `dad-guard-copilot.ps1:62-77` at `:641` are all correct. Ironic in
  a contract whose thesis is that silent drift between doc and code is the enemy.

- **Quality:** High. The header comments on `dad-guard-copilot.ps1:1-21` and the inline notes at
  `install.ps1:305-307`, `test-kit.ps1:1346-1349`, `uninstall.ps1:84-87` all explain WHY (the silent-failure
  trap) rather than restating WHAT, matching the surrounding idiom. `[CmdletBinding()]` on the adapter
  (`:26`) follows the kit's stated reason (models typo parameter names). `-Check` passthrough (`:34-37`) is a
  nice touch: a human can ask "would this block?" without knowing the adapter exists. Temp-file-instead-of-pipe
  with the PS 5.1 quoting reason given (`:48-51`) is the kind of note that prevents a future "simplification"
  regression. Every failure path ends in `exit 0` (`:41,78-84`). ASCII-clean throughout; `install.cmd` already
  passes args through (`install.cmd:10`), so `install.cmd -CopilotCli` needs no change.
  **Two specific defects:**
  1. Drift detection uses SUBSTRING matching: `install.ps1:269` and `dad-doctor.ps1:501` do
     `$cv -notmatch [regex]::Escape($measured)`. A future `1.0.890` or `11.0.89` CONTAINS `1.0.89`, so it
     would report `[ok] matches the measured contract` on an unmeasured harness. That is a (narrow)
     false-negative in the one mechanism C2f installs to prevent silent drift.
  2. `dad-guard-copilot.ps1:64` uses `'\{.*\}'` (greedy, single-line). Safe TODAY only because
     `dad-guard.ps1:53` emits `-Compress`d JSON; if any future guard path emits multi-line JSON or prose on
     stdout before the brace, the adapter silently falls to the synthesized-reason branch. The synthesized
     branch is a safe fallback, so this degrades rather than breaks - worth a comment pinning the dependency
     on `-Compress`.

- **Hygiene:** Mostly clean; two gaps. (a) `README.md` documents `-Cloud` (`:94-96`, `:135`) and `-Hybrid`
  (`:97`, `:143`) but never mentions `-CopilotCli` - a user-facing opt-in installer switch with no user-facing
  documentation outside DESIGN.md and the installer's own comment block. (b) `dad-doctor.ps1:464-506` has no
  dedicated behavioral test case; `test-kit.ps1:1469-1470` only asserts HOW it reads the version constant, so
  the section's gating condition (`:469`, silent unless hooks installed or `copilot` on PATH), its stale-kit-path
  warn (`:490-492`) and its WARN branches are covered by the reported manual run and nothing else. Given the
  kit's own convention that `dad-doctor` is where drift surfaces, that is the second-thinnest point after AC6.
  The 2 reported `test-kit.ps1` failures were confirmed pre-existing against a clean stash baseline
  (corpus SHELL-door case; an `examples/cms3/cms.db` artifact dated 11 days earlier), so they are not S12's.
  `docs/STORIES.md:474` still carries `<!-- Status: TODO -->` with AC1-AC5 ticked - presumably for close-unit
  to flip, but worth confirming it does get flipped.

- **On the story card being written AFTER delivery:** the card is honest about it -
  `docs/STORIES.md:483-484` says so in plain words ("Delivered ahead of this card by the ... research pilot
  (commit 64188cc); the card exists so the work is gradeable and closeable through the normal gate, not to
  schedule new work"). I checked whether the ACs are retrofitted rubber stamps by reading each named test
  before reading the AC text: AC2, AC3 and AC4 are real behavioral/assertive tests that would FAIL on a
  plausible regression (AC2 case 2 catches "blocks every stop"; AC3 case 2 catches over-eager deletion; AC4
  catches a stale version constant). AC1 is partly retrofitted - its install-side assertions were clearly
  written to match `install.ps1`'s existing source text rather than its behavior. AC6 is the opposite of
  retrofitted: it is left UNCHECKED, which a card written to flatter the work would not have done.

- **Verification mode (ACs touching real machine state):**
  - **AC1 (hook file shape):** verified **live-sandboxed** in test - the assertions run against the in-repo
    template and a sandbox, never `%USERPROFILE%`. The install-side rewrite is **code-review-only** (source
    grep at `test-kit.ps1:1375-1376` plus my own read of `install.ps1:286-298`).
  - **AC2 (adapter):** verified **live-sandboxed** - `test-kit.ps1:1390-1427` executes the real adapter in a
    `New-Sandbox` temp dir against stub guards; no real machine state touched.
  - **AC3 (uninstall):** verified **live-sandboxed** via the `-ClaudeDir`/`-CopilotDir` overrides
    (`test-kit.ps1:1440,1444`), the exact override pattern S1's note establishes; the real
    `%USERPROFILE%\.copilot\hooks` is never the target.
  - **AC4 (version constant):** **static/code-review**, correctly - it is a doc-vs-source consistency check
    with no machine state involved.
  - **AC5 (live Copilot CLI):** **live, NOT sandboxed** - it wrote to the real `%USERPROFILE%\.copilot\` (a
    hooks file and three probe agents) and scaffolded a throwaway project outside the kit. The story's Dev
    note (`docs/STORIES.md:520-523`) records this and states both were removed and `~/.copilot/` confirmed
    returned to stock. I am relying on that written record; I did not and cannot inspect `%USERPROFILE%`
    from this grading pass to confirm the cleanup independently.
  - **AC6 (`install.cmd -CopilotCli` live):** **DEFERRED - neither live nor code-review-substituted-silently**,
    per R35(b), and stated as such on the card. Correct call; it remains a real open item.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [human] **Run `install.cmd -CopilotCli` once, with consent, before relying on the Copilot gates on this
   machine** - and close AC6 by amending `docs/STORIES.md:515-519` with the date it ran. This is the only
   S12 code path (`install.ps1:258-314`) that nothing automated has ever executed, and the failure it could
   hide is precisely C2's thesis failure: an installer that reports success and wires a gate that never fires.
   Whether the current substitute (static case + manual replay) is sufficient to close a story is a judgment
   call, not something I should stamp.
2. [dev] **Fix the drift check's substring comparison** at `install.ps1:269` and `dad-doctor.ps1:501`:
   `$cv -notmatch [regex]::Escape($CopilotMeasuredVersion)` reports "matches the measured contract" for any
   version STRING CONTAINING `1.0.89` (e.g. `1.0.890`, `11.0.89`). Extract the version with a
   `([0-9]+(\.[0-9]+)+)` capture and compare for EQUALITY, and add a test case feeding a fake
   `copilot --version` line to prove the warn fires - C2f's only drift mechanism currently has no behavioral
   test at all, in either consumer.
3. [dev] **Make the install-side JSON rewrite behaviorally testable instead of source-grepped.** Replace
   `test-kit.ps1:1375-1376`'s `'\$h\.bash\.Replace'` source regex with a test that performs the transformation
   (or calls a small extracted `Set-CopilotHookRoot`-style helper) and asserts the OUTPUT contains the real
   root and no trace of `C:\Projects\Claude\MCP\DAD-kit` - the same lesson `uninstall.ps1:17-19` already
   records about pinning implementation details, and it would let AC1 stand without the manual replay.
4. [mechanical] **Refresh C2's stale `install.ps1` line citations** in `docs/DESIGN.md`: C2a `:588` says
   `install.ps1:262-265` (actual write is 282-285), the worked example `:681` says `install.ps1:266-284`
   (actual rewrite is 286-298), invariant (v) `:723` says `install.ps1:293` (actual restart notice is 313).
   The `test-kit.ps1` and `dad-guard-copilot.ps1` citations are correct and need no change. DESIGN.md is
   LOCKED, so this is a citation-accuracy edit only - no requirement or decision text changes.
5. [dev] **Give `dad-doctor.ps1:464-506` one behavioral test case** (sandbox a fake hooks dir + a fake kit
   root; assert the section stays SILENT with no hooks and no `copilot` on PATH, WARNs on a dad.json pointing
   at a different kit path, and OKs on a matching one). Today its only coverage is the manual run plus the
   two C2f source assertions.
6. [mechanical] **Document `-CopilotCli` in `README.md`** next to `-Cloud`/`-Hybrid` (`README.md:94-97` and
   the mode prose at `:135-143`): one paragraph saying it is additive (both harnesses on one machine), that
   it needs `npm install -g @github/copilot` + Node 22+, that Copilot must be RESTARTED to pick up hooks, and
   that `uninstall.ps1` removes it. Right now the only user-facing description of the switch lives in
   DESIGN.md and an installer comment.
7. [mechanical] Add one line at `dad-guard-copilot.ps1:64` noting the `'\{.*\}'` match depends on
   `dad-guard.ps1:53` emitting `-Compress`d single-line JSON, so a future change there degrades this adapter
   to its synthesized-reason fallback rather than failing loudly.
