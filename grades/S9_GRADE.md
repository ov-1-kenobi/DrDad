# Story S9 - Structured gate decision log (R38) : report card

**Current grade: B+**  (as of 2026-09-29, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-29        | B+    | initial story-level grade: helper + four writers + tests all land and match C3; AC3 only indirectly met, several known edge gaps |

## Assessment (this iteration)
Read: dad-gates-log.ps1 (all), dad-loopguard.ps1:205-380, dad-guard.ps1:45-110, ratchet.ps1:40-60 plus call sites (196, 209, 245), close-unit.ps1 call-site grep (48-53, 286-656), STORIES.md S9 (359-387), DESIGN.md C3b-C3f (851-990). I did NOT read the test bodies in test-kit.ps1 (only located them by grep: 5009-5144, 5376, 5536, 5723) and did not run anything, so test claims below are structural only.

- Correctness: matches intent. Append path is redact -> truncate pipeline in `Get-CleanReason` (dad-gates-log.ps1:44-49: collapse, redact via scan-secrets patterns, truncate 300, in C3a order). Seven keys in fixed order via OrderedDictionary (:91-98). Lines UTF-8 no BOM, LF (:100). 4096-byte guard (:101). Fail-open: top-level try/catch, `exit 0` (:182-183). If patterns cannot load, nothing is written (:89), which honours invariant (ii).
- Acceptance:
  - AC1 covered. loop-guard heartbeat at dad-loopguard.ps1:353-361 (armed allow on first call, marker file created), blocks at :367/:372/:377. dad-guard-stop logs every Block (dad-guard.ps1:72). ratchet logs every verdict (ratchet.ps1:196, 209, 245). close-unit logs block at each refusal site (close-unit.ps1:286, 321-330, 360-375, 423, 494, 652) and allow at :537/:656. Gap to verify: I did not confirm dad-guard's "armed" allow line on the first Stop (grep of dad-guard.ps1 showed only `Write-GateLog "block"` at :72; the allow-armed path was not seen in what I read).
  - AC2 covered. Query mode (dad-gates-log.ps1:52-84): `-Gate` is the filter, `-Decision`, `-Since` (TryParseExact on the C3b ts format, :71), `-Last`, `-Count`; human note to STDERR (:58), `-Count` prints 0 on missing log (:59), verbatim lines output (:82). Fixes all three T9.1 defects named in C3e.
  - AC3 only indirectly met. No file among grade-trends.ps1, retro.md, dad-doctor.ps1, gates-smoke references `gates-log` (grep count 0). "Can read" is true via `-Query`, but nothing consumes it. DESIGN lists actual consumption as a non-goal, so this is a wording gap in the AC, not a defect.
- Design: C3c revision is correctly implemented. `FileSystemRights.AppendData` + `FileShare.ReadWrite`, single Write (dad-gates-log.ps1:174-175), retry 40/80/160 ms with jitter (:167-179); comment at :170-173 records the measured PS 5.1 loss, and DESIGN C3c (892-919) was amended to match, so code and contract agree. C3d genesis: CreateNew race-safe path (:156) writes genesis + own line in one Write, newest predecessor chosen by name date then mtime (:117-125), matches both worked examples' wording (:115, :138). Not a ratcheted surface: ratchet.ps1:98 filter stays `*_GRADE.md`. C3f (smoke SILENT-FAIL "<gate>-log", doctor age) is not in this story's files; not verified here and likely S8/other scope.
- Quality: good, heavily commented with the why. Duplication: four near-identical Write-GateLog wrappers (ratchet.ps1:52, close-unit.ps1:48, dad-guard.ps1:52, dad-loopguard.ps1:236), each re-doing whitespace collapse, quote swap and 300 cap, and two re-implementing project-root discovery (dad-guard.ps1:55-61, dad-loopguard.ps1:223-233). Accepted cost of the startup-speed constraint, but a drift risk. Empty `-Tool` is handled consistently (omitted; dad-loopguard.ps1:240,245; dad-guard.ps1:65) - the known drop is real but the callers are correct. Double quotes in reasons are rewritten to `'` at the callers, so logged reasons differ slightly from the console text (C3b's worked example shows `\"`).
- Hygiene: dad-gates-log.cmd exists and is tested (test-kit.ps1:5142-5144); scan-secrets.ps1 has the `-PatternsOnly` switch (:60) with a test that normal scanning is unchanged. Log committed on each clean close means it grows per unit (C3d says manual roll only; acceptable, doctor WARN at 5 MB is the mitigation, not verified here).
- Verification mode: no AC here touches real machine state outside the project/temp dir. The loop-guard state marker lives under `$env:TEMP\dad-loopguard` (dad-loopguard.ps1:356). Tests appear to use sandbox project dirs (test-kit.ps1:4985+ helper); I did not read them, so behavior is code-review-only from me. Whether the suite pollutes real `%TEMP%\dad-loopguard` was not checked.

Known-item verdicts:
- C3c revision: correct and documented (above). Good catch by QA.
- Unescape-Json `\\t` -> TAB: confirmed avoided for cwd via a dedicated single-pass unescape (dad-loopguard.ps1:335-337); the pre-existing bug still affects `$cmdMatch` at :366 (command matching, not logging).
- dad-guard cwd fallback: `$proj` defaults to process cwd when payload cwd empty (dad-guard.ps1:107) and Write-GateLog then may write into that dir (:53-66, walks up to a docs/grades ancestor, else uses $proj itself, creating grades/ there). This is inconsistent with loop-guard, which SKIPS when cwd is empty (dad-loopguard.ps1:353, 367). Should be aligned.
- `-SkipVerify` suppresses close-unit logging including blocks, and first close in a fresh project logs no ratchet line: both are silent-evidence gaps against C3b's "EVERY invocation" table. I did not trace those branches beyond the grep, so treat as reported-not-verified.
- `-AcceptShrink` still logs a ratchet block: reasonable (the gate did block), but it makes a deliberate override look like an intervention in C4 counts.
- T9.4 duplicated coverage: cost is suite time only; harmless.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Make dad-guard skip logging when the hook payload has no cwd (dad-guard.ps1:107 fallback + :52-66), matching loop-guard, so a Stop hook cannot create `grades/` in an arbitrary process cwd.
2. [dev] Close the "EVERY invocation" gaps for ratchet/close-unit: log an allow (or a distinct reason) on the no-baseline first-close branch, and decide/log for `-SkipVerify`. Confirm dad-guard emits the first-Stop "armed" allow (AC1); add a test if missing.
   Correction (hygiene pass): the "confirm dad-guard emits the first-Stop armed allow" doubt is resolved - it exists at dad-guard.ps1:168 (`Write-GateLog "allow" "armed"`) and is covered by the T9.2 (b) test. Only the no-baseline and -SkipVerify gaps stand.
3. [design] Reword S9 AC3 to something testable ("`-Query` output parses with ConvertFrom-Json"), or split "grade-trends/retro consume the log" into its own story; today AC3 is unfalsifiable and nothing consumes the log.
4. [design] Decide whether a close with `-AcceptShrink` should log `block` (current) or a separate reason marker, since C4 counts interventions from this log.
5. [mechanical] Factor the four duplicated Write-GateLog arg-sanitising blocks only if a shared dot-sourced helper does not cost startup time; otherwise leave and add a comment cross-referencing the copies.
   Applied (hygiene pass): comment cross-referencing the four copies added; code NOT merged (hot-path startup cost, loopguard stays regex-only).
6. [dev] Fix Unescape-Json's sequential replace (dad-loopguard.ps1:366 path) - pre-existing, flip the characterization test; needs its own story/task first.
7. [human] Whether committing the log on every clean close (repo growth) is acceptable versus gitignoring it or committing only on roll; C3a currently says COMMITTED.
