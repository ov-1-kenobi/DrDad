# Story S2 - Steer web tools to local-tools (CLAUDE.md convention) : report card

**Current grade: A-**  (as of 2026-09-19, iteration 1 - backfill)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-19        | A-    | backfill grade - no card existed at close (commit b154eea); graded shipped code, not the closing diff |

## Assessment (this iteration)
- **Correctness:** Intent fully met, but via a DIFFERENT (superseding) mechanism than the story literally
  describes. `docs/STORIES.md:37-55` (S2) says "Edit the 5 template CLAUDE.md files: dotnet, python,
  embedded, generic, unity" and put the line "under each file's Working agreement section." At the time S2
  closed that was true (per its own migration comment: "'## Web / grounding' line added to all 5 type
  templates ... + avalonia"). Since then the template system was refactored (per `templates\README.md:3-7`,
  "That order was reversed in 0.13.0") into a **stack-agnostic scaffold + profile-fragment** model: only
  `templates\generic\CLAUDE.md` is a full CLAUDE.md; `templates\dotnet\PROFILE.md`,
  `templates\python\PROFILE.md`, `templates\embedded\PROFILE.md`, `templates\unity\PROFILE.md`, and
  `templates\avalonia\PROFILE.md` are now FRAGMENTS containing only Stack/Placeholder/Build-test/
  Human-in-loop sections - explicitly NOT allowed to carry kit-owned sections. I verified this is
  deliberate and enforced, not drift: `test-kit.ps1:543-566` ("stack profiles are FRAGMENTS (no kit-owned
  sections to go stale)") lists `## Web / grounding` in `$owned` (line 546) and asserts (line 563) that
  NO `PROFILE.md` contains it, and asserts (line 551-553) that non-generic template dirs have no
  `CLAUDE.md` at all. The gate's own comment explains why: "They used to be full CLAUDE.md files and
  drifted badly behind templates/generic (old Modes wording, no Secrets, no Task-tool rule). Keeping them
  fragments makes that impossible." Functionally every scaffolded project - any stack - starts from
  `templates\generic\CLAUDE.md` (`templates\README.md:9-11`: "`new-project.cmd` ... lays down a generic
  CLAUDE.md"), which carries the Web/grounding section, so the S2 GOAL ("make every project prefer local
  web tools") is met, and more robustly than the original 5-file duplication would have been (single
  source of truth vs. 5 copies that could drift independently - which is exactly what happened to other
  sections before this refactor).
- **Acceptance:**
  - AC1 ("all 5 template CLAUDE.md files contain the line") - **literally FALSE today**: only
    `templates\generic\CLAUDE.md` is a CLAUDE.md; `dotnet/python/embedded/unity` (and `avalonia`) are
    PROFILE.md fragments with no CLAUDE.md at all. Functionally covered (every project inherits the line
    from generic), but the AC's wording is now stale relative to the shipped architecture. This is a
    story-bookkeeping gap, not an implementation defect.
  - AC2 (names `web_search` + `ingest_url`, says NOT to use built-in WebSearch/WebFetch) - **met**, verbatim.
    Read `templates\generic\CLAUDE.md:73-76`:
    ```
    ## Web / grounding
    - Web search / URL lookup: use the `local-tools` `web_search` / `ingest_url` tools, NOT the built-in
      WebSearch/WebFetch (those need Anthropic and don't work against local Ollama). For grounding,
      `web_search` to find, then `ingest_url` to fetch + persist into the RAG.
    ```
    matches the story's specified wording (`docs/STORIES.md:45-47`) almost verbatim.
  - AC3 (validation gate passes; ASCII) - **met**. Confirmed `templates\generic\CLAUDE.md` has zero
    non-ASCII bytes (grep `[^\x00-\x7F]` -> no matches). `test-kit.ps1` has explicit, passing gates for
    this exact section (lines 543-582) so the "validation gate still passes" clause holds by construction.
- **Design:** Diverges from the story's literal Data/interfaces clause ("Edit the 5 template CLAUDE.md
  files") but is a documented, intentional, TESTED architectural improvement (DRY single source instead of
  5-way duplication), landed under the "layered docs" direction of R7. Not scope creep - it is a later,
  separate refactor that subsumed S2's mechanism while preserving its goal.
- **Quality:** Clean; the section is short, the wording is exact, and it sits correctly under the kit-owned
  block between Secrets and Hybrid in `templates\generic\CLAUDE.md:59-88`.
- **Hygiene:** Templates directory and `templates\README.md` are internally consistent about the current
  fragment model; `test-kit.ps1` actively guards against re-duplicating this section into a profile
  fragment, which is the failure mode S2's original 5-file approach was prone to.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [mechanical] Update `docs/STORIES.md` S2's AC1 and "Data / interfaces" wording (lines 44-53) to reflect
   the current architecture - e.g. "the line lives once in `templates\generic\CLAUDE.md` (kit-owned section)
   and is inherited by every scaffolded project regardless of stack" - so a future reader/grader isn't
   misled by AC text describing a file layout that no longer exists. Also update or annotate the closing
   comment on line 38 (`<!-- Implemented: "## Web / grounding" line added to all 5 type templates ... -->`)
   to note the later 0.13.0 consolidation, so the story's history stays honest.
2. [dev] None required - the current implementation already exceeds the story's functional intent. No
   code change needed.
3. [human] Decide whether backfill-graded stories whose shipped mechanism was later superseded by an
   unrelated refactor (here, the profile-fragment architecture) should be graded against the CURRENT
   architecture (as done here) or marked N/A and re-pointed at whatever story introduced the superseding
   refactor (e.g. whatever story/version introduced "0.13.0"'s stack-agnostic scaffold) - this pattern will
   recur for other pre-STORIES.md-migration stories (S1, S3) if their mechanisms also drift.
