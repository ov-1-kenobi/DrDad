# Story S29 - install.ps1 defaults to Cloud, Local is explicit : report card

**Current grade: A-**  (as of 2026-10-09, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-09        | A-    | initial grading of the completed story (T29.1-T29.9) |

## Assessment (this iteration)
- Correctness: install-mode.ps1:8-48 implements C6 resolution exactly: conflict check first (lines 13-18), explicit flag wins with Hybrid > Cloud > Local (20-24), no flag reads the env block, base-URL -> Local/kept, LOCALTOOLS_HYBRID=1 -> Hybrid/kept, else Cloud (25-40), unparsable file -> Cloud plus a Warn naming the file (30). Reason strings match the C6 banner wording (42-46). The function is pure.
- Acceptance: AC1/AC2 covered by the end-to-end sandbox case and the dad-doctor case. AC4 (pinned default) is covered by the resolver case. AC5 README is updated (README.md:142-144, 195, 203 now say no flag is Cloud and `-Local` is the resilience mode). I did not open overview/*.html and I did not run the suite, so "0 failed" is unverified by me. AC3 is only partly covered: `-Hybrid` is tested (row 3), but `-CopilotCli` combined with the new modes has no S29 case.
- Design: install.ps1:23 adds `[switch]$Local`. Lines 29-31 resolve the mode and `exit 1` on conflict before any write. Lines 36-37 rebind `$Hybrid`/`$Cloud` so later code follows the resolved mode. The single tell is unchanged (no marker file). dad-doctor hints name `install.cmd -Local`, asserted at test-kit.ps1:1317-1318. Scope stays inside C6.
- Quality: the resolver is small and readable. The test seam `DAD_INSTALL_SANDBOX` (install.ps1:44-48) is env-only and inert when unset. Weaknesses: the wiring checks at test-kit.ps1:1267-1275 are source-regex checks, which are brittle (for example `'Conflict\)[^\r\n]*exit 1'`). The `$Cloud = [switch]($mode -ne 'Local')` rebind is slightly confusing, because Hybrid also sets `$Cloud`.
- Hygiene: DESIGN.md:1576-1578 still says C6 is "Not yet implemented ... install.ps1 still treats a no-flag run as Local and has no -Local switch". That is now false. I did not check CHANGELOG 0.59.0 beyond the commit title.
- Verification mode (AC touching machine state): AC1/AC2 were verified live-sandboxed. The case at test-kit.ps1:1322-1402 sets USERPROFILE/HOME to a TEMP home, sets DAD_INSTALL_SANDBOX, narrows PATH, asserts the sandbox paths sit under TEMP (1345), and snapshots the real User Path, DAD_HOME, Ollama vars, settings.json and .bashrc before and after (1341, 1399-1400). The real machine was confirmed untouched by that design. This was by reading the test code; I did not run it. The conflict case (test-kit.ps1:1277-1288) runs install.ps1 for real against an empty sandbox profile and asserts nothing was written.
- Tests by name: "S29 AC1-AC4: install mode resolution follows C6 ..." (test-kit.ps1:1231, rows 1-9), "S29 AC1/AC2: dad-doctor reads Cloud and Local back ..." (test-kit.ps1:1292), "S29 AC1/AC2: a real install.ps1 run in a sandbox profile honors C6 ..." (test-kit.ps1:1322, rows 1, 5, 2, 4, 7, 3).

## Suggestions (prioritized; tag each so the team knows who acts)
1. [design] Update the stale C6 status at docs/DESIGN.md:1576-1578 from "Not yet implemented" to implemented (S29 DONE). DESIGN is LOCKED, so this needs the human's confirmation.
2. [dev] Close the AC3 gap: add a sandboxed case in test-kit.ps1 (near line 1322) that runs `-CopilotCli` combined with the default and with `-Local`, to show it still combines with every mode. Add a case for `-Local -Cloud` through the real installer, not only through the resolver (test-kit.ps1:1255).
3. [dev] Replace the source-regex wiring asserts at test-kit.ps1:1267-1275 with behavior (the conflict run at 1277 already proves the exit-before-write). Then drop the brittle text matches.
4. [mechanical] Add a comment at install.ps1:36-37 saying that `$Cloud` stays true for Hybrid on purpose.
5. [human] Confirm that overview/*.html no longer says "no flag is Local". I did not read those files, and the full-suite `0 failed` should be confirmed by a fresh run.
