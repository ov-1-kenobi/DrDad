# Story S20 - The local-tools MCP server must not index an empty placeholder docs dir either (R24) : report card

**Current grade: A-**  (as of 2026-09-30, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-30        | A-    | first card for S20; T20.1 (02289ff) Rag.cs/Program.cs rule and T20.2 (1bdb033) test case READ |

## Assessment (this iteration)
Read: docs/STORIES.md:825-871 (S20), docs/TASKS.md:1894-1924 (T20.1, T20.2), local-tools/Rag.cs:20-105 (flag type,
roots, rule, predicate), local-tools/Rag.cs:315-328 / 355 / 385 / 409-410 / 525 (DescribeCorpus and every
CreateDirectory), local-tools/Program.cs:1-88 (all CLI entry points + MCP start), test-kit.ps1:2810-2948 (existing
multi-root case and the new S20 case). Not run: build/tests, and `git show` (assessor has no shell; commit contents
were judged from the files at HEAD on branch r39/s20-server-docs-dir).

- Correctness: good. `DocsRootSource.Explicit` is a separate static class (local-tools/Rag.cs:26-29), exactly as
  T20.1 step 1 requires, so Rag's static initializers cannot read it before Program sets it. Program sets it inside
  the same `if` as the env-var assignment for `--reindex` (local-tools/Program.cs:11), `--ingest` (local-tools/Program.cs:27)
  and `--corpus` (local-tools/Program.cs:55), before any `Rag.` call; `--search` (local-tools/Program.cs:39-47) and the MCP
  server path (local-tools/Program.cs:76-88) leave it false, so they are env-var-sourced as the story says. The rule
  (local-tools/Rag.cs:81-95) runs only on `seen[0]`, only when not explicit, substitutes `<cwd>\docs` only if that
  passes and differs, de-dups it from later roots, and writes the exact WARN text via `Console.Error` (local-tools/Rag.cs:93).
  Env var unset keeps the datasheets fallback (local-tools/Rag.cs:68). Predicate includes CORPUS.md (local-tools/Rag.cs:101-103).
- Acceptance: all eight ACs have code + a test in "T20.2 / S20 AC1-AC5, AC7, AC8: the server's env-var docs-dir rule
  (--corpus, no Ollama)" (test-kit.ps1:2841-2948). AC1 2881-2889 (first root, index path, WARN on stderr naming both
  dirs, nothing on stdout); AC2 2891-2896; AC3 2898-2903 (exit 0, primary kept); AC4 2905-2923 (empty dir untouched
  after --corpus, and a real `--reindex` against a missing override creates nothing there while `.index` lands under
  proj\docs - stronger than asked, since --corpus alone never creates folders); AC5 2925-2930; AC7 2932-2937; AC8
  2939-2946. AC6 is the gate itself - not run by me, unverified here. Gaps: (a) the whole case silently `return`s
  when `-SkipBuild` or the exe is missing (test-kit.ps1:2846-2848), so it can count as green without running - the
  same weakness flagged for S19; (b) AC5's third assert uses an OR (`finding\.md|2 indexable file\(s\)`,
  test-kit.ps1:2930), which is looser than it needs to be.
- Design: matches T20.1 to the letter. `IndexDir`/`WebDir` now derive from `DocsRoots[0]` (local-tools/Rag.cs:58-63),
  so BuildRoots runs once (one WARN) and `.index`/`web`/`derived` follow the substituted primary - the
  CreateDirectory calls at local-tools/Rag.cs:385, 409-410 and 525 needed no edit. BuildRoots creates no directory and
  never writes stdout. docs-dir.ps1, .mcp.json and corpus.ps1 were not touched (scope respected). The comment block
  at local-tools/Rag.cs:55-57 documents the rule as asked.
- Quality: small, readable, well-commented. Edge case not handled: after substitution the nested-root skip
  (local-tools/Rag.cs:75-76) is not re-applied, so an env value like `<empty>;<proj>` from cwd `<proj>` makes
  `<proj>\docs` primary while `<proj>` stays a secondary root that contains it - files under docs would be walked
  twice. Rare (needs a parent of the cwd docs in the list), but the existing code goes out of its way to prevent
  exactly that double count. Minor: the marker array is re-allocated per HasProjectDocs call (trivial). The predicate
  now intentionally diverges from docs-dir.ps1 (CORPUS.md is server-only per the 2026-10-01 decision) - two copies of
  the rule to keep in sync.
- Hygiene: no csproj/dependency change needed; only System.IO/Linq used. The test restores `LOCALTOOLS_DOCS_DIR`
  in `finally` (test-kit.ps1:2865-2867, 2919-2921) and cleans its sandbox (2947). install.cmd re-run is left to the
  human, as the story requires; whether it has been done is not visible to me.
- Verification mode: the ACs touch a process env var only. The test sets it in the test process and restores it
  exactly (unset vs set) and every fixture is a New-Sandbox %TEMP% dir, so it is live-sandboxed by design; the real
  placeholder `C:\Projects\Claude\MCP\DAD-kit\docs` and real .mcp.json are never touched. My own verification is
  code-review-only (no shell). Note the AC4 `--reindex` leg will really call Ollama if it is running locally (sandbox
  data only, bounded by a 60 s timeout at test-kit.ps1:2918) - harmless, but it is a live side effect.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Re-apply the nested-root filter after substitution in local-tools/Rag.cs:87-94 (drop any secondary root
   that contains or is contained by the new `cwdDocs`), and add an assert for env `"$empty;$proj"` from cwd `$proj`
   in the S20 case (test-kit.ps1:2925-2930) expecting no double count.
2. [dev] Make the S20 case (test-kit.ps1:2846-2848) emit an explicit SKIP/WARN instead of a bare `return` when the exe
   is missing (same fix suggested for S19's docs-find case), so a skipped run cannot read as a pass.
3. [mechanical] Tighten test-kit.ps1:2930 to assert `finding\.md` and the file count separately rather than OR-ing them.
4. [human] Confirm `install.cmd` has been re-run so the installed local-tools.exe carries the rule (S20 Data/interfaces
   says re-run install; dev was told not to), and decide whether the duplicated predicate (local-tools/Rag.cs:101-103 vs
   docs-dir.ps1) should get a test pinning the intended CORPUS.md divergence.
