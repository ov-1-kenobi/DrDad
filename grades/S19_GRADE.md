# Story S19 - A stale or empty LOCALTOOLS_DOCS_DIR must not hide the project's real docs (R24) : report card

**Current grade: A-**  (as of 2026-09-30, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-30        | A-    | first card for S19; T19.1 (82b9048) helper + wiring and T19.2 (f327dd5) tests READ |

## Assessment (this iteration)
Read: docs-dir.ps1 (all 27 lines), wiring hits in doc-stats.ps1:98-99, docs-find.ps1:36-37, close-unit.ps1:215-216,
dad-doctor.ps1:20 and 395-412, test-kit.ps1:1946-2009 (S19 fixtures and 4 cases) and 1104, STORIES.md S19 (787-823),
kit .mcp.json:6. Not run: build/tests (assessor is read-only). corpus.ps1 was not opened; only grep-confirmed it does not reference the helper.

- Correctness: good. One helper, Resolve-DocsDir (docs-dir.ps1:5-27). The override is honoured only if it is a real
  container holding DESIGN.md, TEDD.md or STORIES.md (15-19); otherwise it returns `<proj>\docs` and prints the exact
  WARN text from the story (22-24). An unparseable .mcp.json or a thrown Test-Path falls back silently to `<proj>\docs`
  (10, 20). It never creates a directory. Passing overrides return the resolved path (21), so no WARN.
- Acceptance: AC1 covered by test-kit.ps1:1962-1974 (empty dir -> WARN naming the path, "0/2 done" from the project's
  own docs, override dir still empty). AC2 covered by 1976-1988 (override with STORIES.md, 3 stories read, no WARN).
  AC3 covered: docs-find case 1990-2002, plus a structural case 2004-2009 pinning that doc-stats/docs-find/close-unit/
  dad-doctor use the helper and corpus.ps1 does not. AC4 is the gate; not run by me, unverified here.
  Gaps: (a) the docs-find case silently returns when the exe is not built (1991), so it is a skip counted as a pass;
  (b) close-unit and dad-doctor have only the grep-level "references Resolve-DocsDir" test, no behavioural case
  (the story allows "shares the helper's" case, so acceptable); (c) the "missing dir" path is covered by the older
  test at ~1917-1943, not re-asserted for the WARN line.
- Design: matches. Shared helper, dot-sourced (not per-script variants). corpus.ps1 deliberately exempt, as the dev
  note requires, and pinned by a test. Placeholder in .mcp.json untouched (.mcp.json:6), no C# change. docs-dir.ps1 is
  excluded from the "every .ps1 is a command" inventory check (test-kit.ps1:1104). The dad-doctor behaviour is a
  deliberate variant: it calls Resolve-DocsDir -Quiet (dad-doctor.ps1:405) and emits its own Say "WARN" "docs dir"
  line (408) naming the ignored path and the fallback, instead of repeating the helper's raw WARN line. That fits
  the doctor's OK/WARN/FAIL table and is sound. Note the branch at 407 (override differs textually but resolves to the
  same dir, e.g. a trailing slash or relative path) is a good catch and keeps the doctor from false-warning.
- Quality: small, readable, commented header. Minor: the $ok loop does not break after the first hit (16-18),
  harmless. The doctor's three-way if/elseif (406-409) duplicates the helper's pass/fail rule only indirectly via
  comparing $dd to $rd, which is clever but subtle; a later change to the rule stays consistent since it derives from
  the helper's result.
- Hygiene: test-kit inventory exemption added (1104). No manifest change needed: scripts run from the kit dir via
  $PSScriptRoot / $kit, so nothing needs copying by install. No new dependencies.
- Always-WARN concern: the kit's OWN .mcp.json holds the dev placeholder `C:\Projects\Claude\MCP\DAD-kit\docs`
  (.mcp.json:6). On any machine where that path does not exist or holds no DESIGN/TEDD/STORIES (the normal case
  unless install.cmd rewrote it), every doc-stats/docs-find/close-unit run inside the kit repo prints the WARN, and
  dad-doctor WARNs on every run for the kit itself. It is truthful and harmless (fallback is the right dir), but it is
  permanent noise in the kit's own runs and trains readers to ignore WARN lines, which weakens the signal the
  story exists to provide. Also, doc-stats' WARN goes to Write-Host; if a caller parses doc-stats output it now
  may see an extra line (Write-Host is not on the success stream, so captured objects are unaffected, but `2>&1 | Out-String`
  callers and the tests do see it).
- Verification mode: no AC touches real machine state. All S19 cases run in New-Sandbox temp dirs with a fixture
  .mcp.json; the real kit .mcp.json and real docs were not modified. Verified by code/test review, not live run by me.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Make the docs-find AC3 case (test-kit.ps1:1991) report an explicit skip/WARN rather than a silent `return`
   when the exe is missing, so it cannot read as green without running.
2. [human] Decide how to treat the kit's own placeholder: accept the permanent WARN when working in the kit repo,
   or suppress it when the override equals the literal placeholder string (a small helper tweak, but it would hide a
   genuine "install never rewrote this" symptom in a project, so it is a judgment call).
3. [dev] Add one behavioural case for close-unit or dad-doctor (for example dad-doctor on a fixture with an empty
   override expecting the "docs dir" WARN at dad-doctor.ps1:408), instead of relying only on the grep-level case at
   test-kit.ps1:2004-2009.
4. [mechanical] Add `break` after `$ok = $true` in docs-dir.ps1:17 (tidy only; behaviour unchanged).
