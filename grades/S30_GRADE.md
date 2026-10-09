# Story S30 - Ratchet counts derived test attributes; -AcceptShrink records its reason : report card

**Current grade: A-**  (as of 2026-10-09, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-09        | A-    | initial grading of the completed story (T30.1-T30.5)  |

## Assessment (this iteration)
- Correctness: ratchet.ps1:78-120 scans .cs/.fs/.vb for `class X : bases` (ratchet.ps1:87), normalises
  namespace-qualified and `Attribute`-suffixed names (ratchet.ps1:84-85), blanks comments and strings first
  (ratchet.ps1:86, so a `FactAttribute` mention in a comment or string is not a base), iterates to a fixed
  point (ratchet.ps1:100-108, so derived-of-derived is found) and widens `$testMarkers` with a lookbehind and
  lookahead alternation that handles `[X]`, `[X(...)]`, `[Trait(..), X]` (ratchet.ps1:112-114). Counting
  stays per line via Select-String (ratchet.ps1:123). Find-ShrunkFiles (ratchet.ps1:176+) uses the same
  widened `$testMarkers` for the baseline blob (ratchet.ps1:188), so a [Fact] -> [RealIpfsFact] conversion
  shows no shrink.
- Fail-open: the catch at ratchet.ps1:116-120 falls back to base markers and prints a note. The
  DAD_RATCHET_FAIL_DISCOVERY=1 hook (ratchet.ps1:83) makes AC5 testable. Matches DESIGN R28 (docs/DESIGN.md:208).
- close-unit: `-Reason` handling at close-unit.ps1:492-499 (warning when no reason, note when reason but no
  shrink) and the `Shrink-accepted: <reason> (human)` trailer at close-unit.ps1:619, with a confirmation
  note at close-unit.ps1:631 and a gate-log allow text at close-unit.ps1:501. Reason-less calls are unchanged.
- Acceptance: AC1-AC4 are covered by test-kit.ps1:2704 ("S30 AC1/AC3/AC4: converting [Fact] to a derived
  attribute keeps the ratchet count, ...") and test-kit.ps1:2743 ("S30 AC2: derived attribute variants are
  counted, comment/string mentions are not"). AC6 is covered by test-kit.ps1:2827, AC7 by test-kit.ps1:2886.
  AC5 is covered by test-kit.ps1:2789 ("S30 AC5: a discovery error falls back to the base markers with a note and the same exit code"),
  which drives the DAD_RATCHET_FAIL_DISCOVERY hook. (Corrected by the orchestrator: the first draft of this card said no AC5 case existed.) AC8 and AC9 are claimed by T30.5 and the log
  (commit 76f29b8); I did not re-run the suite or the real gdn1 ratchet (assessor, no shell).
- Design: no DESIGN edits needed (docs/STORIES.md:1246); recover-lost.ps1 untouched, only pinned by a test.
  Scope held; the known limits ([Fact(Skip=..)] not counted) were left alone as the story required.
- Quality: reasonable, well commented. Minor: the discovery is regex-based, not a parser, so
  nested/generic edge cases (multi-line base lists, partial classes split across files) are best effort.
- Hygiene: CHANGELOG 0.59.1 entry present per T30.5 (not re-read line by line). No new dependencies.
- Verification mode: AC8 touched a real external repo (D:\projects\GalacticDataNetwork\gdn1). Per STORIES.md
  and T30.5 it was a read-only ratchet run (no -Update) that appends one gates-log line to gdn1; I could not
  confirm that from the code, so it is claimed-by-task, code-review-only on my side. Other ACs ran on
  sandbox fixtures (New-Sandbox).

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] None outstanding: the AC5 case exists (test-kit.ps1:2789); the earlier suggestion to add one was a grading error.
2. [dev] Add a fixture for a derived attribute whose class declaration spans lines or whose bases are
   split by a generic, to document the regex's limits (ratchet.ps1:87).
3. [human] Decide whether to widen the markers to `[Fact(Skip=...)]` and `[Fact, Trait(...)]`
   (pre-existing gap noted in docs/STORIES.md:1238); it would raise counts across projects.
4. [mechanical] None found.
