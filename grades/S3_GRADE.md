# Story S3 - Avalonia project template (templates\avalonia) : report card

**Current grade: A-**  (as of 2026-09-19, iteration 1 - backfill)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-19        | A-    | backfill grade - no card existed at close (commit dce52c5); graded shipped code, not the closing diff |

## Assessment (this iteration)
- **Correctness:** Intent fully met, but via a DIFFERENT (superseding) mechanism than the story literally
  describes - the same 0.13.0 template refactor identified in `grades/S2_GRADE.md` also touched
  `templates\avalonia`. At close, per S3's own migration comment (`docs/STORIES.md:58`), the story shipped
  `templates\avalonia\CLAUDE.md` (a full file) plus a Types row in `templates\README.md` and relied on
  `/scaffold avalonia` auto-listing that subfolder. Today there is no `templates\avalonia\CLAUDE.md` at
  all; instead there is `templates\avalonia\PROFILE.md` (read in full), a FRAGMENT containing only Stack /
  Placeholder convention / Build-test-run / Project-file hygiene / Human-in-loop sections, explicitly
  excluding the kit-owned Modes/Design-doc/Working-agreement sections (per its own header comment,
  `templates\avalonia\PROFILE.md:2-4`: "A FRAGMENT, not a CLAUDE.md... Kit-owned sections... come from
  templates/generic/CLAUDE.md - never duplicate them here"). This is deliberate and enforced, not drift:
  `test-kit.ps1:543-566` ("stack profiles are FRAGMENTS") iterates every `templates\*` dir except
  `generic`/`_common` (so avalonia is in scope), asserts a `PROFILE.md` exists, asserts NO `CLAUDE.md`
  exists, and asserts none of the 6 kit-owned sections (`## Modes`, `## Design doc`, `## Working
  agreement`, `## Web / grounding`, `## Secrets`, `## Proven recipes`) appear in it - avalonia's PROFILE.md
  passes all three checks as read. `templates\README.md:30` lists `avalonia/` in the current Stack
  profiles table ("C# / .NET cross-platform desktop UI (Avalonia 11 / XAML, MVVM)" / "`dotnet build` /
  `dotnet test` / `dotnet run`"), and `global\commands\design.md:34-38` names `avalonia` in `/design` step
  2's profile list ("dotnet | web | avalonia | python | embedded | unity"). So the STORY GOAL ("add an
  avalonia project type so a project can be set up as a cross-platform .NET XAML desktop app") is met,
  now through the two-step scaffold(stack-agnostic)+`/design`(picks stack, copies the fragment) flow rather
  than a stack-named `/scaffold avalonia`.
- **Acceptance:**
  - AC1 ("CLAUDE.md exists with the Modes block + build/test/run + MVVM placeholder + visual
    human-in-loop") - **partially stale, functionally covered differently**. There is no
    `templates\avalonia\CLAUDE.md` and, by design, no Modes block in `PROFILE.md` (Modes is kit-owned,
    lives once in `templates\generic\CLAUDE.md`, inherited by every scaffolded project regardless of
    stack). The MVVM placeholder convention, dotnet build/test/run, and visual human-in-loop content ARE
    present, verbatim in spirit: `templates\avalonia\PROFILE.md:15-17` (Placeholder convention - MVVM,
    in-memory/mock behind interfaces, design-time data, `// TODO`), `:19-23` (Build/test/run, including the
    `Avalonia.Headless.XUnit` / `[AvaloniaTestApplication]` detail called out in the story), `:31-33`
    (Human-in-loop visual - "hand me a 'run `dotnet run` and check' plus a Visual Inspection checklist -
    I'm the eyes for look/feel"), matching the story's Behavior section almost word for word
    (`docs/STORIES.md:76-81`).
  - AC2 ("templates\README.md Types table lists avalonia") - **met**, though the table's shape changed
    (now "Stack profiles" not "Types", per the 0.13.0 rename) - `templates\README.md:25-33`, avalonia row
    present with correct description and build/test/run.
  - AC3 (ASCII; validation gate passes) - **met**. Grepped `templates\avalonia\PROFILE.md` for
    `[^\x00-\x7F]` - no matches. `test-kit.ps1`'s fragment-shape and no-version-pin gates (lines 543-582,
    confirmed the fragment-shape block directly) apply generically to every `templates\*\PROFILE.md`
    including avalonia's, so "gate still passes" holds by construction, not by story-specific code.
  - AC4 ("manual: `/scaffold avalonia` appears in the menu and scaffolds a project") - **literally FALSE
    today**. `global\commands\scaffold.md:1-19` (read in full) takes only `general|experience` as its
    argument (KIND, not stack) and explicitly says "STACK is decided FIRST inside `/design`" (line 10) and
    "Do NOT fill the stack in yet" (line 23) - there is no per-stack `/scaffold <stack>` menu anymore. The
    functional replacement is `/design` step 2 presenting `avalonia` as one of the profile choices
    (confirmed above), which is a strictly later point in the same overall flow. This AC needs a manual
    human run to confirm end-to-end (unchanged caveat from the original story), but as WRITTEN it describes
    a UI surface that no longer exists.
- **Design:** Diverges from the story's literal Data/interfaces clause ("new file
  templates\avalonia\CLAUDE.md") but is the same documented, tested, kit-wide architectural change already
  identified for S2 (DRY single source for kit-owned sections instead of N-way duplication per stack) -
  not scope creep, a later refactor that subsumed S3's mechanism while preserving its goal and even
  improving fidelity to the story's own Behavior text (the fragment content maps almost 1:1 to S3's
  Behavior bullets).
- **Quality:** Clean. `templates\avalonia\PROFILE.md` is well-organized, mirrors `templates\dotnet\PROFILE.md`'s
  structure/wording (compared directly), correctly tells the implementer to detect the installed
  toolchain/Avalonia version rather than hard-coding one (`:8-11`), and includes a "Project-file hygiene"
  section not explicitly required by S3's AC list but consistent with the dotnet profile's pattern (mild,
  reasonable scope addition, not creep).
- **Hygiene:** `templates\README.md` and `global\commands\design.md` both list avalonia consistently with
  the current fragment architecture; `test-kit.ps1`'s generic per-stack-dir loop actively guards avalonia
  against reintroducing a `CLAUDE.md` or a kit-owned section, so there is no drift risk left unguarded.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [mechanical] Update `docs/STORIES.md` S3's AC1 ("Modes block") and AC4 ("`/scaffold avalonia` appears in
   the menu") wording (`docs/STORIES.md:86,89`) to match the current two-step scaffold+`/design` flow - e.g.
   AC1 -> "PROFILE.md exists with build/test/run + MVVM placeholder + visual human-in-loop (Modes is
   kit-owned, inherited from generic)"; AC4 -> "(manual) `/design` step 2 offers avalonia as a stack choice
   and correctly fills CLAUDE.md's Stack/Build/Placeholder/Human-in-loop from PROFILE.md." Also annotate the
   closing comment on line 58 to note the later 0.13.0 consolidation, matching the annotation already
   suggested for S2.
2. [dev] None required for the shipped artifact - `templates\avalonia\PROFILE.md` already meets the
   story's functional Behavior bullets under the current architecture.
3. [human] AC4 is still genuinely unverified end-to-end: run `/design` on a fresh scaffold, pick `avalonia`
   at step 2, and confirm CLAUDE.md gets the Stack/Build-test-run/Placeholder/Human-in-loop sections copied
   correctly from `templates\avalonia\PROFILE.md` with no leftover kit-owned duplication. Same
   backfill-grading policy question raised in `grades/S2_GRADE.md` suggestion 3 applies here too (S1 likely
   next).
