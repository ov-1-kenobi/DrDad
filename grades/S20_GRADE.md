# Story S20 - The local-tools MCP server must not index an empty placeholder docs dir either (R24) : report card

**Current grade: A-**  (as of 2026-09-30, iteration 2)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-30        | A-    | first card for S20; T20.1 (02289ff) Rag.cs/Program.cs rule and T20.2 (1bdb033) test case READ |
| 2    | 2026-09-30        | A-    | all cites re-verified after hygiene (+1 line in Rag.cs after HasProjectDocs, AC5 assert split in test-kit.ps1); old suggestion 1 refuted (CorpusFiles dedupes); suggestion 3 applied |

## Assessment (this iteration)
Read (line numbers re-verified against the files as they are NOW): docs/STORIES.md:825-870 (S20), docs/TASKS.md:1894-1924
(T20.1, T20.2), local-tools/Rag.cs:20-106 (flag type, roots, rule, predicate), local-tools/Rag.cs:316-351 (DescribeCorpus,
CorpusFiles), local-tools/Rag.cs:356 / 386 / 410-411 / 526 (DerivedDir and every CreateDirectory), local-tools/Program.cs:1-88
(all CLI entry points + MCP start), test-kit.ps1:2810-2949 (existing multi-root case and the new S20 case). Not run:
build/tests, and `git show` (assessor has no shell; commits were judged from the files at HEAD on r39/s20-server-docs-dir).

- Correctness: good. `DocsRootSource.Explicit` is a separate static class (local-tools/Rag.cs:26-29), as T20.1 step 1
  requires, so Rag's static initializers cannot read it before Program sets it. Program sets it inside the same `if`
  as the env-var assignment for `--reindex` (local-tools/Program.cs:11), `--ingest` (local-tools/Program.cs:27) and `--corpus`
  (local-tools/Program.cs:55), before any `Rag.` call; `--search` (local-tools/Program.cs:39-47) and the MCP server path
  (local-tools/Program.cs:76-88) leave it false, so they are env-var-sourced as the story says. The rule
  (local-tools/Rag.cs:81-95) touches only `seen[0]`, only when not explicit, substitutes `<cwd>\docs` only if that passes
  and differs, de-dups it from later roots, and writes the exact WARN text via `Console.Error` (local-tools/Rag.cs:93).
  Env var unset keeps the datasheets fallback (local-tools/Rag.cs:68). Predicate includes CORPUS.md (local-tools/Rag.cs:101-103).
- Acceptance: all eight ACs have code + a test in "T20.2 / S20 AC1-AC5, AC7, AC8: the server's env-var docs-dir rule
  (--corpus, no Ollama)" (test-kit.ps1:2841-2949). AC1 test-kit.ps1:2881-2889 (first root, index path, WARN on stderr
  naming both dirs, nothing on stdout); AC2 2891-2896; AC3 2898-2903 (exit 0, primary kept); AC4 2905-2923 (empty dir
  untouched after --corpus, and a real `--reindex` against a missing override creates nothing there while `.index`
  lands under proj\docs - stronger than asked); AC5 2925-2931 (now four separate asserts: first root, shared listed,
  finding.md listed at 2930, exact `2 indexable file(s)` at 2931 - the split hygiene applied); AC7 2933-2938; AC8
  2940-2947. AC6 is the gate itself - not run by me, unverified here. Remaining gap: the whole case silently `return`s
  when `-SkipBuild` or the exe is missing (test-kit.ps1:2846-2848), so it can count as green without running - the same
  weakness flagged for S19.
- Design: matches T20.1. `IndexDir`/`WebDir` derive from `DocsRoots[0]` (local-tools/Rag.cs:58-63), so BuildRoots runs
  once (one WARN) and `.index`/`web`/`derived` follow the substituted primary - the CreateDirectory calls at
  local-tools/Rag.cs:386, 410-411 and 526 needed no edit. BuildRoots creates no directory and never writes stdout.
  docs-dir.ps1, .mcp.json and corpus.ps1 untouched (scope respected). Comment block at local-tools/Rag.cs:55-57
  documents the rule.
- Quality: small, readable, well-commented. Iteration 1 claimed a double-count edge case when a substituted
  `<cwd>\docs` sits inside a secondary root; that is REFUTED - see Suggestions. Minor: the marker array is re-allocated
  per HasProjectDocs call (trivial). The predicate intentionally diverges from docs-dir.ps1 (CORPUS.md is server-only
  per the 2026-10-01 decision, docs/STORIES.md:866-870) - two copies of the rule to keep in sync.
- Hygiene: no csproj/dependency change needed. The test restores `LOCALTOOLS_DOCS_DIR` in `finally` (test-kit.ps1:2866,
  2920) and cleans its sandbox (test-kit.ps1:2948). install.cmd re-run is left to the human, as the story requires;
  whether it has been done is not visible to me.
- Verification mode: the ACs touch a process env var only. The test sets it in the test process and restores it
  exactly (unset vs set) and every fixture is a New-Sandbox %TEMP% dir, so it is live-sandboxed by design; the real
  placeholder `C:\Projects\Claude\MCP\DAD-kit\docs` and real .mcp.json are never touched. My own verification is
  code-review-only (no shell). The AC4 `--reindex` leg will really call Ollama if it is running locally (sandbox data
  only, bounded by a 60 s timeout at test-kit.ps1:2918) - harmless, but a live side effect.

## Suggestions (prioritized; tag each so the team knows who acts)
1. ~~[dev] Re-apply the nested-root filter after substitution (double count for env `<empty>;<proj>` from cwd `<proj>`).~~
   REFUTED (iteration 2): CorpusFiles() collects files from every root and returns
   `outp.Distinct(StringComparer.OrdinalIgnoreCase)` (local-tools/Rag.cs:350), and excludes IndexDir
   (local-tools/Rag.cs:344-345). A file reached through both `<proj>` and `<proj>\docs` has the same full path, so it is
   indexed once. No action.
2. [dev] Make the S20 case (test-kit.ps1:2846-2848) emit an explicit SKIP/WARN instead of a bare `return` when the exe
   is missing (same fix suggested for S19's docs-find case), so a skipped run cannot read as a pass.
3. ~~[mechanical] Split the OR'd AC5 assert.~~ APPLIED by hygiene: now test-kit.ps1:2930 (finding.md) and
   test-kit.ps1:2931 (exact file count).
4. [human] Confirm `install.cmd` has been re-run so the installed local-tools.exe carries the rule (the S20
   Data/interfaces section says re-run install; dev was told not to), and decide whether the duplicated predicate
   (local-tools/Rag.cs:101-103 vs docs-dir.ps1) should get a test pinning the intended CORPUS.md divergence.
