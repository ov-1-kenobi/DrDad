# Changelog

All notable changes to DAD-kit. Versions follow semver; the requirement ids (R1-R21) are in `docs/DESIGN.md`.

## 0.19.2 - 2026-08-21

Three bugs found by scaffolding a fresh project and looking at what the model actually receives on turn
one. Two of them were exposed by making the mistake a model would make.

### Fixed - a mistyped parameter ran against the DEFAULT instead of failing
A `.ps1` with a plain `param()` block is **not an advanced function**, so PowerShell drops unmatched
arguments into `$args` and carries on with the defaults - silently. `new-project.ps1 -Kind general
-Path C:\tmp\x` therefore ignored `-Path` entirely and scaffolded into the CURRENT directory: `CLAUDE.md`,
`.mcp.json`, `docs\` and a `git init` landed one level above an existing checkout. No warning.

**16 of 21 scripts** were exposed this way, including every writer (`close-unit` was already safe via
`[Parameter()]`). They all now carry `[CmdletBinding()]`, so a bad parameter is a hard error naming the
offending switch. This matters because these scripts are invoked by MODELS, which typo parameter names,
and nearly all of them take a `-ProjectDir` that defaults to `.`.

### Fixed - a failed `git init` left a repo with NO commits
git accepts `init` in a folder containing other repositories, warns about an embedded repo, and then fails
the commit - leaving a `.git` with no HEAD. That is strictly worse than no repo: the ratchet has no
baseline, `recover-lost` has nothing to diff against, and `dad-guard` sees every file as untracked forever,
while the project *looks* version-controlled to every gate. `new-project` and `upgrade-project` now refuse
to init around existing repos (naming them, and saying to use an empty folder), verify a commit actually
EXISTS with `rev-parse --verify HEAD` rather than trusting that nothing threw, and delete the half-made
repo if it does not. The scaffold itself still completes - no git is a degraded mode, not a failure.

### Fixed - the kit still told you to decide the stack LATE
0.13.0 reversed that rule and the reversal never reached six other surfaces: `new-project`'s closing
advice, the README's mode table, `/scaffold` (twice), `/design`'s own frontmatter description - and the
heading of the very section the model fills in, which read *"Solution architecture (decide LATE - once
requirements + epics are stable)"* with a comment underneath saying *"Do NOT pick a stack up front"*. A
project scaffolded yesterday was being told the opposite of what `/design` step 2 does. The existing test
only checked `design.md`, and its pattern (`decide LATE`) did not even match `decided LATE`. It now sweeps
all six surfaces case-insensitively.

### Tests
104 cases (was 102). Two new: mistyped parameters rejected (asserted statically AND behaviourally), and the scaffold
never leaving a baseline-less repo. Two seeded RECIPES traps added - `[CmdletBinding()]`, and matching
captured output with `\s+` because console output is hard-wrapped mid-phrase (that one broke two
assertions in this release before it was understood).
## 0.19.1 - 2026-08-21

A pre-flight re-check of 0.19.0 before running it on real hardware. Four misses, one of which could have
wedged a project.

### Fixed - the security gate could DEADLOCK
0.19.0's Gate 2b had exactly one exit: run `/design`, which spawns `security-agent`. But every tool that
agent has is an MCP tool, and `search_datasheets` was called ZERO times across nine graded runs - decent
evidence the `local-tools` server is not always connected. Unconnected server -> the agent cannot work ->
the header stays `REQUIRED` -> Gate 2b stops `/build`. The project is wedged by missing plumbing, and the
gate's own advice is to run the thing that does not work.

Fail-closed on infrastructure is how a gate gets switched off, so:
- Gate 2b now states BOTH routes when it stops: run `/design`, **or** set `NOT-REQUIRED (<reason>)`
  deliberately. The model may not take the second one itself - it states it and waits.
- `/design` has a branch for the agent coming back unable to search: say so, do not relay a review, do not
  leave `REQUIRED` standing with no route forward. It names `/mcp` and `dad-doctor` to diagnose.
- `security-agent` must report "could not search" and return rather than answering from memory. A plausible
  undated review is worse than none, because `/design` pins it and everything downstream treats it as
  decided.

### Fixed - "under 6 months old" was not actually checked
`source-stats -StaleDays 180` measured the **fetched** date. In a fresh run everything was fetched today, so
the flag could not catch anything on the first pass - the only pass that matters. A 2019 article pulled this
morning read as current. R31's central claim (recency is checkable, a model's memory is not) was enforced by
prose.

`docs/SOURCES.md` gained a **`published`** column - the page's own publication or last-updated date, or the
literal word `undated`. It is the LAST column deliberately: parsing is positional, so inserting it beside
`fetched` would make every pre-existing ledger read its title as a date. Verified against a five-column row.
Old publication dates WARN, never FAIL - a blocking recency gate gets switched off. `research-agent` and
`security-agent` both fill it, and are told not to copy the fetch date into it.

### Fixed - two silent-nothing bugs, and a static check for the whole class
`upgrade-project` referenced `$docs`, a variable that only exists in `doc-stats.ps1` - the third bug of this
exact shape in one release (0.19.0's was `$designFile`, from `ratchet.ps1`). None of them errored:
PowerShell resolves an unknown variable to `$null`, so `Test-Path $nothing` is false and the check quietly
passes forever. **A gate that cannot fail is indistinguishable from no gate**, which is this kit's whole
premise, so the suite now parses every `.ps1` and reports any variable READ that the same file never
assigns. It self-checks against a synthetic reproduction of the real bug first, because an analyser that
finds nothing on clean code proves nothing about itself.

It immediately caught a bug in its own first draft: PowerShell variable names are **case-insensitive**, so
a type held in `$V` was being overwritten by `foreach ($v in ...)`. That is now a seeded RECIPES trap too.

### Fixed - experience projects warned forever
`TEDD.md` had no `Security review:` header, so every experience project would report a missing-header
warning permanently. Added, with the note that an experience is often legitimately `NOT-REQUIRED` - until
there is a leaderboard, an account, an upload, or telemetry.

### Added - upgrade-project names the header
It deliberately does NOT inject `Security review: REQUIRED` into an existing project: that would block the
very next `/build` of work that was running fine. It now prints the one-line edit for both answers and lets
the human choose.

### Verified, not assumed
`web_search` is a keyless DuckDuckGo HTML scrape, so no API key is needed - and the scrape still works
today (HTTP 200, 10 `a.result__a` anchors, matching the selector `Rag.cs` queries). Worth knowing it is a
scrape: if `web_search` ever returns nothing, that selector is the first place to look.

### Tests
102 cases (was 99).
## 0.19.0 - 2026-08-21

Two changes aimed at the two things the kit demonstrably gets wrong on real projects: it builds parts it
never assembles, and it has no answer on security.

### Changed - S1 is a WALKING skeleton (R30)
A project reached **183 passing unit tests across 12 building projects, with a 20-line host and zero
integration tests, having never once served a request.** Every part worked; the thing did not exist. Its S1
was *"create solution skeleton with warnings as errors"* - build configuration - so every story after it
added to a pile nobody had assembled.

The first story must now prove the system **end to end**, however trivially: one request in, one response
out, through the real layers, with an integration test against a real store. Every later story then extends
something that RUNS, and `close-unit`'s test gate means INTEGRATION from the first close rather than mocks.
Written into the STORIES template, `/stories`, `scribe-agent` and `/taskmap`.

This is probably worth more than any gate in the last five releases.

### Added - `security-agent` + a gated `Security review:` header (R31)
Auth, input handling and secret management are where a green test suite tells you least - tests pass over a
subtly unsafe implementation - and retrofitting them after a dozen stories is how the insecure version
ships.

- The design doc carries **`Security review: REQUIRED | NOT-REQUIRED (<why>) | DONE <date>`** next to
  `Status:`. `doc-stats -Findings` computes it; **`/build` Gate 2b refuses to start while it says
  REQUIRED.** An absent header (older project) is a WARNING, not a block.
- `/design` decides it **once the stack is known** - which is exactly why 0.13.0 reversed R7 to choose the
  stack first - and ASKS. REQUIRED by default; `NOT-REQUIRED (poc, no auth, never deployed)` is a legitimate
  answer with the reason recorded, so a later reader knows it was a decision and not an omission.
- **`security-agent` exists because recency is checkable and a model's memory is not.** It goes ONLINE for
  guidance under ~6 months old, records each source's publication date, prefers the originating authority
  over commentary, and searches deprecation and advisories SEPARATELY from "how do I do X" - a pattern that
  was correct two years ago may now name a deprecated API or a library that has since had a CVE.
- It pins one cited line per decision into `## Security decisions`, **writes no code**, and may not flip the
  header itself - the human approves. `/design` gates the citations with `source-stats -StaleDays 180`
  instead of the default year, because security guidance ages faster than anything else here.
- The most valuable thing it can return is *"use the framework's built-in and do not build this yourself"*,
  which is the common case for auth.

### Added - RECIPES ships pre-loaded
`close-unit` records the commands a project verified, which is worth nothing on day one - and day one is
exactly when a model writes `&&` into PowerShell 5.1 and loses the turn. The template now ships the traps
that have actually broken a run of this kit, in the same field format `close-unit` writes: multi-line
`git commit -m @'...'@` mangling the message (hit while committing THIS release), `Set-Content -Encoding
UTF8` writing a BOM, `if` in expression position, single-element unrolling so `.Count` is `$null`,
`Test-Path ""` throwing, and `&&`/`||` being a 5.1 parser error. Every one of them PARSED and then
misbehaved, which is why "it ran without a syntax error" is not evidence.
### Tests
99 cases (was 96). The walking-skeleton rule present in the template and all three story-writing surfaces
with the old bare-title placeholder gone; and the security header flagged when REQUIRED, silent on DONE and
NOT-REQUIRED, reported-but-not-blocking when absent, plus the agent held to recency, decisions-only and
not-setting-its-own-header.

### Fixed
`doc-stats`'s new check referenced `$designFile`, a variable that only exists in `ratchet.ps1` - so it
silently did nothing. Caught by the test, which is the only reason it is not shipping broken.
## 0.18.1 - 2026-08-21

Three things runE exposed, all of them "the mechanism existed and was never used".

### Added - duplicate unit ids are a computed finding
`STORIES.md` had **every story twice** (28 headings, 14 distinct ids) and `TASKS.md` carried a stray
"RECOVERED" block - and nothing noticed. The close was clean, so the ratchet baselined the **doubled**
counts as its floor; runE's repair then read as a regression (`stories 28 -> 14`). `doc-stats -Findings`
now reports `[scribe] DUPLICATE story id S1 - appears 2x (lines 12, 384)`. Verified against the real
corrupted commit: it catches all 29 doubled ids and reports zero on the repaired docs.

### Added - `docs-find.ps1` / `.cmd`: the corpus has a shell door
`search_datasheets` has been called **zero times in nine graded runs.** In the same run, `doc-stats.ps1`
was called 17 times and Bash 94. The prose telling agents to prefer the MCP tool has been in `dev-agent`,
`qa-agent` and `/build` the whole time and has never worked once - so this is the same corpus behind the
interface that demonstrably gets used. It also answers when the MCP server is NOT connected (a stale
`.mcp.json` path, a server that failed to start) - exactly when you most need a lookup and least expect to
fail - and falls back to a literal scan when Ollama is down. `local-tools.exe --search "<query>" [topK]`
underneath.

### Fixed - RECIPES.md stops being empty
It was designed as a proven-commands log agents append to on success. After nine runs on a real project it
held **18 lines: the bare template, zero entries.** Asking a model to remember to write down what worked is
the same class of instruction as asking it to remember to run `close-unit`, and it failed the same way -
while runs kept emitting broken shell (one used bash syntax with a two-segment-wrong path,
`cd D:/projects/mediamotor_iiif`, and lost the turn). So `close-unit` now records the build and test
commands it just VERIFIED, into a `## Verified by close-unit` table, once per distinct command.

### Tests
96 cases (was 93). Duplicate ids detected with their line numbers and not invented on clean docs;
`docs-find` answering with no Ollama, exiting non-zero on no match, and offered by all three call sites;
`close-unit` writing the verified commands and not duplicating them on the next close.
## 0.18.0 - 2026-08-16

0.17.x could detect a shrink and print a `git show`. That is still the wrong recovery, and the real case
proves it twice over.

### Why a whole-file revert is wrong
The change that deleted the tests ALSO added a working `CustomWebApplicationFactory`, a JSON-LD `@context`
fix and a .NET 10 PipeWriter fix. `git checkout` would have discarded all three and re-broken what had just
been fixed. Recovery has to work at the level of **named units** - restore what disappeared, keep what
arrived.

### And a correction to the record
Running the new tool against the actual incident showed **3 of the 15 "deleted" tests had MOVED**, not
been deleted - `GetImage_C9WorkedExampleProducesCorrectOutput` and `GetImage_IIIFLevel2Conformance` are
live `[Fact]` methods in `ComprehensiveIiifTests.cs`. **12 were genuinely lost, not 15.** Earlier changelog
entries and my own reports overstated it. `GetImage_ReturnsByteIdenticalOutputAsNamedVariant` is gone from
the whole tree, so the finding stands - but a blind restore would have created three duplicate tests, which
is exactly the failure the "and sensible" half exists to prevent.

### Added - `recover-lost.ps1` / `.cmd` (R29)
The generic shape it handles, worth learning to recognise: **a change removed far more than it added, the
result still compiles, and nothing looks broken.**

- Diffs **named units** - methods, tests, functions, types, markdown headings - between the working tree
  and the ratchet's baseline commit. Pattern-based, so it covers C#/Java/TS/Python/Go/Rust/JS/Markdown
  without a parser per language.
- **Separates LOST from MOVED**: a unit that still exists anywhere else in the tree was relocated or
  renamed, and restoring it would duplicate it. This is most of what distinguishes a real loss from a
  refactor.
- `-Restore` writes the old content back **commented, under a marker, with the diff command** - a starting
  point for reconciliation, not a merge, because restored code routinely needs a using, a fixture or a
  helper that also changed. Everything the change ADDED stays.
- **Nothing is ever restored without `-Restore`.** Deletion is sometimes correct; a tool that silently
  undoes deliberate work is worse than the problem.
- `ratchet`, `close-unit` and `/build` all route to it now, instead of suggesting a raw `git show`.

### Tests
93 cases (was 92): a rewrite that loses five units, gains one and relocates another - asserting the lost
ones are reported, the ADDED one is not, the MOVED one is excluded from the restore set, `-Restore` keeps
the new work and returns the old commented, a clean tree reports nothing, and all three call sites point
at the tool.
## 0.17.1 - 2026-08-16

0.17.0 could DETECT a shrink. It could not tell you how to undo one.

### The gap
The kit already has recovery machinery - `/audit recover <file>` spawns `librarian-agent` in RECOVER mode,
which does git triage and hands back a restore command, and `/build` routes to it. But it routes there only
when a file is reported **MANGLED**, and a file that lost 14 tests is not mangled: it parses, it compiles,
it is simply smaller. Nothing else would ever flag it.

Worse, the ratchet's own advice was **"Restore it (git has it)"** - no file, no commit, no command. That is
the same unresolvable-advice defect the stop guard shipped with in 0.12.0, repeated by me one release after
writing a test to prevent it.

### Fixed
- **The baseline records the commit it was taken at**, so recovery can be exact rather than "go find the
  right commit yourself" - the difference between a recoverable incident and a lost afternoon.
- **The ratchet names the FILE that shrank**, by comparing each changed file's test-marker count against
  the same file at the baseline commit, and prints a command that runs as written:
  ```
  tests/ApiTests.cs  (15 -> 1 test(s))
      git show <sha>:tests/ApiTests.cs > "tests/ApiTests.cs"
  ```
  It also says **RECONCILE afterwards** - in the real incident the rest of the change (a
  `CustomWebApplicationFactory` for test isolation) was correct and worth keeping. Blind revert would have
  thrown away the good half.
- **`/build` routes a shrink to recovery**, and is told explicitly that a shrink is not a mangled file.

### Tests
92 cases (was 91): the baseline storing its commit, the file being named with its before/after count, the
printed command being runnable and actually returning all 15 tests, the RECONCILE warning being present,
and the guidance not being duplicated in `build.md`.

### Fixed while building it
PowerShell unrolls a single-element return, so one shrunk file came back as a bare object whose `.Count` is
`$null` - and `$null -gt 0` is false, which silently skipped the recovery block in exactly the one-file case
that matters most. `@(...)` at the call site.
## 0.17.0 - 2026-08-15

The trap under every gate in this kit, and the one mechanism that closes it.

### What happened
`/build S10` set out to fix the failing IIIF tests. It rewrote `ImageApiControllerTests.cs` to introduce a
`CustomWebApplicationFactory` - a real and correct fix - and **15 of 16 tests did not survive the rewrite**
(160 lines -> 30; 196 removed, 20 added). Gone: `GetImage_C9WorkedExampleProducesCorrectOutput`,
`GetImage_IIIFLevel2Conformance`, `GetImage_ReturnsByteIdenticalOutputAsNamedVariant` - the acceptance
criteria contract C9 existed to make testable.

The report read `Iiif.Tests | 8 | 3` and **every gate went green**: build passed, tests RAN (11 > 0), tests
PASSED (8), tree clean. None of them compared against what was there before.

The model was not cheating. It was asked to make the tests pass; deleting a red test does that; nothing in
the kit forbade it; and the scoreboard scored it as success. Given an objective that rewards a shortcut and
a gate that applauds it, any model takes it.

### The general shape
**Every gate asked "is X OK right now?" - and a gate of that shape is satisfied by DELETING X.** Five
surfaces were open:

| surface | the shortcut |
|---|---|
| tests | delete a red test -> suite goes green |
| stories / tasks totals | delete an undone unit -> 6/14 becomes 6/9, "progress" |
| contracts / requirements | delete the contract -> nothing left to violate |
| sources | delete the ledger row or the citation -> `source-stats` stops failing |
| CLAUDE.md's `Build:` line | delete it -> close-unit prints "closing WITHOUT verification" and proceeds |

### Added - `ratchet.ps1` / `.cmd` (R28)
Records those counts (plus total grade-card BYTES, so a real assessment cannot be swapped for a passing
stub) on every clean close, and **refuses the next close if any fell**. Wired into `close-unit` BEFORE any
mutation, so nothing is ticked or committed over a shrink. `-AcceptShrink` records a deliberate removal -
an obsolete story deleted on purpose is fine. What it must never be is silent.

**It fails OPEN on its own errors**, like `dad-guard`: a gate that fails closed on its own bugs stops real
work and gets switched off. The first version failed closed and broke three passing close-unit tests, which
is the evidence for the rule rather than an argument against it.

### Tests
91 cases (was 89). Two new: the ratchet reproducing the exact runD deletion (15 tests -> 1) and catching
all five surfaces; and `close-unit` refusing to tick or commit over a shrink, ratcheting only on a clean
close, and lowering the baseline when `-AcceptShrink` is passed deliberately.

### Fixed
- `Test-Path ""` throws, so a project with no design doc crashed the counter. A checker that crashes on a
  legitimately empty project would block every close in it.
## 0.16.0 - 2026-08-13

Three additions: UI work that can actually be gated, brownfield adoption, and a loop that notices when the
system is drifting.

### Added - `ui-agent` + a web stack profile (R25)
Lite web / mobile-web is the case I previously said DAD was bad at, because "correct" is visual and there
is no exit code for taste. That is still true - so `ui-agent` is accountable only for the parts that DO
have one: the build with type errors fatal, tests that drive the thing like a user (**"renders without
crashing" passes on a blank page**), an axe/pa11y run treated exactly like a failing unit test, and the
360px viewport. Visual judgement goes back to you, once, with a specific thing to open and expect; the
agent may never call a visual surface "done" on its own authority. Loading/empty/error states are
acceptance, not polish. `/build` routes a unit with a visible surface here instead of `dev-agent`.

### Added - `/document` + `survey-agent` for brownfield (R26)
The kit assumed greenfield; most work is not. `/document` reverse-engineers an existing codebase into a
DRAFT design doc plus a backlog of what REMAINS - not stories describing finished functionality, which
would make every completion metric meaningless.

**Describe, never invent.** Every claim cites `file:line`; anything read from a name rather than logic is
marked `(inferred)`; "cannot determine X" is a finding, not a gap to fill plausibly. A brownfield doc that
describes an idealised version of the code is worse than none, because every agent downstream then
implements against the fiction. Contracts come from `docs/API-SURFACE.md` - real signatures out of the
compiled assemblies - which is why this works here at all. `survey-agent` is READ-ONLY, works one area per
invocation, and counts tests rather than assuming coverage from a csproj.

### Added - `/retro` + `grade-trends.ps1` (R27)
Grade cards were per-unit islands: each said how ONE story went, and nothing ever asked what kept going
wrong ACROSS units - so the same defect got found, written down, and found again three stories later.

`grade-trends.ps1` computes the half a script can: grade direction, units that needed rework, stub cards,
and recurring themes (a theme in 40%+ of cards is a convention problem, not bad luck). `/retro` proposes
**at most three** changes, each naming what it would have prevented, routed to `CLAUDE.md` (a convention),
`RECIPES.md` (a proven command), `/design` (a missing contract), or - when no prose will stop a recurring
defect - escalated as a request for a GATE in the kit. You approve. A retro that rewrites the conventions
wholesale just makes CLAUDE.md an unread wall, and an unread convention is worse than none.

On a real project it immediately reported `contract adherence` in 11/11 cards and `tests / coverage` in
11/11 - which is a convention gap, not eleven unlucky stories.

### Fixed while building it
- **The grade parser scanned prose for a capital letter.** `\bA\b` matches the word "A", so a card reading
  "A worked example was missing" scored as an A - and it reported the WRONG direction on real data. Grades
  are now read from where a card states them (`**Current grade: X**` / the history table) and verified
  against a fixture whose prose is full of stray capitals.
- **The trend was measured in filename order**, so `S2..S6` counted as "early" and `T2.1..T6.1` as "late"
  even though the tasks were graded first. Now ordered by the dates in each card's history.
- **`$` in a .NET multiline regex matches before `\n`**, so on a CRLF file the row anchor never matched and
  every card counted one grading round. Anchor dropped.

### Tests
89 cases (was 86). Three new: the grade parser resisting prose capitals and ordering chronologically;
`ui-agent` and the web profile carrying real gates and no pinned versions; `/document` and `survey-agent`
being read-only, citation-bound and unable to assert absence.
## 0.15.0 - 2026-08-13

`/audit` was unsafe to say yes to. This makes the state half of an audit computed instead of observed.

### The failure
An `/audit` on a **healthy** project returned seven findings; five were fabricated:

| claimed | reality |
|---|---|
| "DESIGN.md Status: LOCKED header missing" | it is on line 5 |
| "STORIES.md missing `<!-- Status -->` markers for S2-S6" | all 14 stories carry them |
| "TASKS.md has 0 tasks with `[x]`" | 10 are ticked |
| same again, retagged `[dev]` | duplicate of a falsehood |
| "C2PA signing not in the design contracts" | it is contract `C10-b` |

It ran on `qwen3-coder-30b` - not a small model - and the transcript shows **one shell command**: the
`doc-stats` call 0.13.0 added, which had just printed the true numbers. Approving those fixes would have
rewritten a correct header, re-marked marked stories, and re-ticked ticked tasks. 0.13.0 made the dashboard
honest and left the findings free-form; that was half a fix.

### Added (R24)
- **`doc-stats.ps1 -Findings`** generates the state findings: design status, missing Status markers and
  off-vocabulary ones, roll-up disagreement in BOTH directions (a DONE story with open tasks, and an
  all-ticked story not marked DONE), missing/stub grade cards, done units no commit names, orphan test
  projects. It also prints a **`STATE FACTS`** line.
- **`/audit` runs it first**, routes those findings directly, passes STATE FACTS into the librarian as
  ground truth, and **rejects any `[design]`/`[scribe]`/`[taskmap]`/`[grade]` finding that contradicts
  them**. A claimed-missing contract goes through `-Contract <Cn>` before anyone acts on it.
- **`librarian-agent` may no longer author state findings at all.** Its remit is what a script cannot
  settle: scope contamination, traceability judgement, corpus health. It may not assert absence - if it
  cannot find something it says "cannot LOCATE", and the orchestrator checks which is true.

On the project that produced the bad audit, `-Findings` reports real problems the model never saw -
including story S7 marked `COMPLETE` instead of `DONE`, which is why its stories read 5/14 while its task
is ticked.

### Tests
86 cases (was 85). A fixture with a correct header, present markers and ticked tasks must produce NONE of
the fabricated findings, while still catching a genuinely unmarked story, an off-vocabulary marker, a
roll-up gap and a missing card - and not demanding a card that exists.
## 0.14.1 - 2026-08-13

A run halted on a blocker it made up. This closes that hole.

### The failure
`/build 8.3` stopped with *"the contracts C6 and C7 are not present in the DESIGN.md file. This is a
critical gap preventing implementation of Story S8."* Both were pinned - `### C6: Materialization policy`
at line 299, `### C7: Eligibility evaluation` at line 334. It had also QUOTED a `## C5: Azure Storage
Adapters` section with five bullets; the real C5 is "Addressing and metadata keys", and the string "Azure
Storage Adapters" existed nowhere in the project until that run printed it. Nothing was implemented, and
the session ended on the fabricated gap. Contributing: it ran on `qwen3-14b-cc` (the `fast` alias - the
weakest wired model, where `/build` asks for `coder`/`quality`), and it never called `search_datasheets`
once - "searched for 1 pattern" was a grep.

### Added
- **`doc-stats.ps1 -Contract <Cn>`** - exit 0 with the heading and line number if that contract exists,
  exit 1 with the list of contracts that DO exist if it does not. `-Contract *` lists them all. Suffixed
  ids (`C10-b`) resolve. Whether a heading exists is a grep; it must never be a judgement call.
- **`/build` must run that check before relaying a "needs contract" claim.** Exit 0 means the claim is
  wrong: dev-agent goes back with the location instead of the loop stopping. Only a non-zero exit is a real
  gap, and only then does it stop - pinning a contract still belongs to `/design`.
- **`dev-agent` may no longer assert absence.** If it cannot find a contract it expects, it must return
  "cannot LOCATE contract <Cn>", because "I could not find it" and "it does not exist" are different
  claims - and the orchestrator now checks which one is true.

### Tests
85 cases (was 84): a contract that exists reported with its real heading and line, a genuinely absent one
failing while listing what is present, a suffixed id resolving, the full listing, and both `/build` and
`dev-agent` being held to the check.
## 0.14.0 - 2026-08-13

Research first, then design. A new ONLINE mode that builds the project's evidence corpus with provenance,
and a corpus that can now span several folders.

### Added - `/research` (R23)
- **`/research [topic]` + `research-agent`** - the only ONLINE mode; everything after it works offline from
  what you captured. Decompose the topic into questions, `web_search` each, `ingest_url` what is worth
  keeping, record provenance, synthesise into the design doc with `[Snnn]` citations.
- **A deliverable is deliberately NOT required yet.** The contracts layer is deliverable-agnostic, so you
  pin the DATA contracts from what you found and decide later whether it becomes a site, a report or a
  form. That is the point of researching before designing.
- **`docs/SOURCES.md`** - the provenance ledger (id, tier, fetched, title, url, and which question each
  source answers), plus `docs/sources/` for the captured material, both created by `/scaffold` and
  `upgrade-project`.
- **`source-stats.ps1` / `.cmd` is the gate.** Research has no compiler, but this is checkable: a citation
  with no ledger row FAILS (the claim rests on nothing), as does a row whose file has vanished. Untiered,
  uncited, unrecorded and stale sources WARN. It verifies **traceability, not truth** - a perfectly-cited
  wrong number is still wrong, and no script fixes that.
- **Tiering is the human's job.** `research-agent` must always write `unknown`; primary/secondary is the one
  judgement nothing downstream can recover from if a model gets it wrong.
- One writer per doc holds: `research-agent` owns `docs/sources/` + `SOURCES.md` and never touches the
  design doc. **`doc-researcher` stays OFFLINE** - it reads the corpus, this one builds it. Two jobs.
- Captured pages are committed and indexed as PLAINTEXT, so capturing credentials or personal data is
  prohibited outright - the agent reports the URL instead.

### Added - a multi-root corpus
`LOCALTOOLS_DOCS_DIR` accepts a `;`-separated list, so a large or shared research corpus can live on
another drive and still sit under one index. The first root is primary (it owns `.index\`). A root nested
inside another collapses rather than indexing everything twice, and a missing root degrades the corpus
instead of breaking the server. `local-tools --corpus` prints what would be indexed, per root, needing no
Ollama - which is also how the suite tests this without embeddings.

### Tests
84 cases (was 81). Multi-root enumeration including nesting and a missing drive; the citation gate failing
an unbacked `[S003]` and a ledger row with no file, then passing once both are fixed, and warning on
untiered and unrecorded sources; and `/research` being wired with its gate while `doc-researcher` stays
offline.

### Fixed
- `[datetime]::TryParse($s, [ref]$null)` cannot bind in PowerShell 5.1 ("cannot find an overload ...
  argument count 2"). `-as [datetime]` is the idiomatic form and reads better.
## 0.13.0 - 2026-08-13

Three changes, one theme: stop making the model rediscover things that are already knowable.

runA first, because it is why these were worth doing. The stop guard fired six times and the model
complied every time; the working tree ended **clean for the first time in that project's history**;
tasks went 6/16 -> 9/16 with real `close-unit` commits. The remaining waste was elsewhere - one task took
**4h 25m** and its own summary read *"fixed all Azure Table Storage API calls to use proper generic type
parameters"*. That is signature archaeology against a DLL that had the answers.

### Fixed
- **`close-unit` REFUSES to bank new work under an already-closed id.** It does `git add -A`, so it banks
  whatever is dirty under whatever id you pass - which produced a commit titled "T8.1: Implement
  ObjectStore" whose diff was `VariantProcessor.cs` (T7.1's work). Then `t8.1` matched the already-ticked
  `T8.1`, took the idempotent path, and committed T8.2's `MetadataStore` under a no-op close, leaving T8.2
  open with its implementation already in history. An id that is already `[x]` plus pending code is the
  signature of work being filed against the wrong unit, and now stops the close. Case differences are
  reported rather than silently accepted.
- **`/scaffold` and `upgrade-project` now gitignore `.claude/`.** One project reported 313 changed paths;
  247 were agent worktrees. Every project the kit has ever made carried this.

### Changed - the stack is decided FIRST (reverses R7)
"Late architecture" was meant to keep options open. Three graded runs showed it only deferred the
blockers: `CLAUDE.md` has no Build/test command until a stack exists, so `/build` Gate 1 refuses and
`close-unit` can verify nothing; the contracts are stack-flavoured anyway (they name real library types);
and the library API docs cannot be ingested before the libraries are known - which is exactly how one
project shipped 16 compile errors from guessed Magick.NET calls. `/design` step 2 now picks the stack,
fills CLAUDE.md from the profile fragment, and ingests the library docs BEFORE requirements, epics and
contracts. `/scaffold` stays stack-agnostic (it is deterministic and model-free). R7 rewritten; the old
wording is gone from the record, and a test asserts the step order.

### Added - the API surface registry
- **`api-surface.ps1` / `.cmd`** and a `--api-surface` mode in `local-tools.exe`: reflection over the
  project's built assemblies AND its direct NuGet packages, emitting exact public signatures to
  `docs/API-SURFACE.md`. Reflection over metadata, not source parsing - the metadata IS the truth, and it
  covers packages whose source you do not have. It lands in `docs/`, so the EXISTING index carries it: no
  new MCP tool, no new server, `search_datasheets` already finds it.
- **`close-unit` regenerates it after every successful build**, so it cannot drift from the code.
- **A build failure hands the signatures over.** runA made ZERO `search_datasheets` calls, so a registry
  the model has to REMEMBER to consult is worth nothing. The compiler already names what it could not
  resolve (CS1501/1061/0117/7036/1503/0246); `close-unit` looks those identifiers up and prints the real
  signatures inside the failure. The answer arrives without anyone choosing to ask for it - the same
  lesson as the stop guard, applied to knowledge instead of bookkeeping.
- `dev-agent` is told to look up any signature it is unsure of, with the command to do it.

Scoping, learned the hard way: walking every DLL under `bin/` gave 131 assemblies and 3,928 types
(1.2 MB) of transitive dependencies nobody calls. Emission is limited to direct `PackageReference`s and
the solution's own non-test assemblies. **Resolution is not filtered** - `TableClient`'s methods return
`Response<T>` from `Azure.Core`, and dropping that from the resolver made every one of those signatures
unresolvable, so the type emitted one constructor and no methods at all.

### Tests
81 cases (was 76). New: close-unit refusing a wrong-id close (and still allowing the right one); the
design step order with architecture before requirements; the generator producing parameterised, generic
signatures for the kit's own server without leaking framework assemblies; lookup mode resolving a member
to its owning type; the build-failure signature handover being wired; and `.claude/` being ignored.
## 0.12.2 - 2026-08-08

The third and worst instance of one bug: something in a project points at the kit by absolute path, the
kit moves, and nothing repairs it. This one FAILS CLOSED - it blocked every commit in the project.

### Fixed
- **A stale `pre-commit` hook was reported healthy instead of repaired.** `install-hooks.ps1` saw the
  string `scan-secrets.ps1` in the existing hook and returned "already installed" WITHOUT checking that
  the path still resolved. So a hook naming a moved or renamed kit aborted every commit with
  "pre-commit: secret scan failed" - while `upgrade-project` (which calls install-hooks) left it alone
  and `dad-doctor` printed `[OK] pre-commit hook`. Three things agreed the project was fine while no
  commit could be made. It now parses the scanner path out of the hook, and rewrites it when it does not
  exist - on the ordinary path, no `-Force` needed, because `upgrade-project` is what has to fix it.
  A healthy hook is still left byte-identical, and a foreign hook is still never hijacked.
- **`dad-doctor` now validates the hook rather than its presence** - a missing scanner is a FAIL with the
  repair command, not an OK.

### Note
Three releases have now fixed the same shape of defect: `.mcp.json` (0.12.1), the guard's printed
commands (0.12.0), and the pre-commit hook (here). Anything in a PROJECT that names the kit by absolute
path needs an owner that re-resolves it, and `upgrade-project` is that owner.

### Tests
76 cases (was 75): a hook pointing at a vanished kit is repaired without `-Force`, a healthy hook is not
rewritten, a foreign hook is still untouched, and `dad-doctor` calls a broken hook a failure.
## 0.12.1 - 2026-08-08

Two defects a `dad-doctor -ProjectDir` run surfaced. The first is the more serious: it means every
existing project has been silently pointing at a kit folder that may no longer exist.

### Fixed
- **Nothing repointed a PROJECT's `.mcp.json` when the kit moved.** `install.ps1` rewrites only the
  `.mcp.json` files inside the kit folder; `upgrade-project` never touched one at all. So moving or
  renaming the kit left every existing project launching `local-tools.exe` from the old path - and it
  fails SILENTLY, because a dead MCP server just looks like "no `search_datasheets` today". A real
  project was still pointing into the pre-rename kit folder. `upgrade-project` now repoints it (via
  parse/serialize, no BOM), keeping the project's own `LOCALTOOLS_DOCS_DIR` - only the binary moves.
- **`dad-doctor` sent you in a circle.** Its fix hint for a stale `.mcp.json` was "re-run install.cmd",
  which cannot fix a project file. It now names `upgrade-project.cmd`, and says why.
- **`dad-doctor` still handed out a bare `close-unit.cmd`** - the same unresolvable-command defect fixed
  in the guard one release ago, living on in a second file. It now prints the full `powershell -File`
  form with `-ProjectDir`.

### Tests
75 cases (was 73). `upgrade-project` repointing a stale exe path while preserving the docs dir and
writing no BOM; and an assertion that `dad-doctor`'s hints name commands that can actually fix the thing
they are attached to - a fix hint that does not fix is worse than none, because it costs a round trip
before you stop believing it.
## 0.12.0 - 2026-08-07

Everything here comes from one graded run (mediamotor_iiif, run003) - the first in which the stop guard
met a live local model. **It worked.** The guard blocked on turn one, and the model's next action was
`dotnet build` followed by `dotnet test`. Against the previous run on the same project:

| | run002 | run003 |
|---|---|---|
| shell calls | 0 | 163 |
| `dotnet build` / `dotnet test` | 0 / 0 | 25 / 92 |
| blind `Update` edits | 106 | 55 |
| build result | 21 errors | 0 errors, 0 warnings |
| tests actually run | 0 | 157 pass, 16 fail |

Then it failed to land any of that work, for reasons this release fixes.

### Fixed
- **The guard named a command that could not be run.** Its message said `close-unit.cmd -Id ...`, but the
  kit folder is not on PATH on a target machine. The run was blocked, went looking for the script,
  could not find it, and ended with 36 verified-but-uncommitted files. It now emits the full
  `powershell -File "<kit>\close-unit.ps1" ...` form, resolved from `$PSScriptRoot` - always correct,
  even if `install` was never re-run. A gate that demands an action has to name it exactly.
- **The guard was blind to new source FOLDERS.** `git status --porcelain` collapses an untracked
  directory to a single `?? src/` entry, which has no file extension and so slipped through the
  code-file filter. A session that created a new source tree registered as "no uncommitted code
  changes". Now uses `-uall`.
- **The guard blamed the session for inherited dirt.** It fired on turn one over 35 files left by the
  PREVIOUS session, with "this is exactly how a run produces thousands of unverified edits" - an
  accusation about work it had not done. It now compares file mtimes against the session start (taken
  from the transcript the harness passes on stdin), blocks only on what THIS session changed, and
  reports the rest as context. A guard that opens by crying wolf is one everybody learns to scroll past.
- **The librarian reported counts it never computed.** The audit said "STATUS.md has been refreshed with
  current progress metrics" without once running `doc-stats`. Telling an agent to run a script is not a
  gate. `doc-stats.ps1 -UpdateStatus` now GENERATES the `## Snapshot` block of `docs/STATUS.md`
  (idempotently, preserving the librarian's prose sections), and `/audit` runs it BEFORE spawning the
  librarian. The model no longer owns any number it could estimate instead.

### Tests
73 cases (was 70). Four new, each reproducing a defect above from the shape that caused it: code hidden
inside an untracked directory; a hook payload whose transcript post-dates the dirty files; the emitted
command text containing a resolvable path; and `-UpdateStatus` producing correct counts, keeping the
prose, and not stacking a second Snapshot on every audit.
## 0.11.2 - 2026-08-06

Hotfix: `dad-doctor` reported a WARN on a perfectly good install.

### Fixed
- **The stop-guard path check flagged healthy installs.** It looked for the substring
  `DAD-kit\dad-guard` to detect an un-rewritten dev placeholder - but a kit correctly installed to
  `D:\projects\Claude\MCP\DAD-kit\` contains that substring too, because the folder is simply NAMED
  DAD-kit. It now compares against this kit's resolved path, the way the `.mcp.json` check already did,
  and distinguishes three cases: wired here (OK), still on the placeholder (WARN), or pointing at a
  different copy of the kit (WARN, naming the expected path).

### Tests
70 cases (was 69). The rule is exercised against all three cases using a REAL directory named
`DAD-kit` - a made-up `D:\...` path would not do, because `Join-Path` THROWS on a drive that does not
exist, leaving the comparison null and `-like "**"` matching everything. That is how the first version
of this test passed the healthy case for the wrong reason.
## 0.11.1 - 2026-08-06

Hotfix: `install.cmd` died at the model step with "The term 'if' is not recognized". Reported from a
real install on the target machine.

### Fixed
- **`sync-models.ps1` used `if` where PowerShell expects an expression.** The BORDERLINE warning built
  its message with `$((if($mf.assumeVramGb){...}else{16}))`. A `$( )` subexpression accepts statements,
  but the extra INNER parens make it an expression context, where `if` is read as a command name. The
  budget is now resolved once, before the loop. Shipped in 0.9.9 with the KV-cache work.
- Same family, two more sites (`sync-models.ps1`, `dad-doctor.ps1`): `$x = if (c) { a }` with `elseif`
  on the NEXT line. PowerShell ends the assignment at the closing brace and reads the next line as a
  command -> "the term 'elseif' is not recognized". Rewritten as plain statements.

### Why the suite missed it
Both shapes are **valid syntax** - `[Parser]::ParseFile` reports zero errors - so "all .ps1 parse" was
never going to catch them. They fail only when the line executes. And the line never executed here:
`sync-models -Report` exits immediately on a machine with no ollama, so the existing test passed without
running one line of the report. A test that passes for the wrong reason.

### Tests
69 cases (was 66). Three new:
- **`sync-models -Report` run END TO END against a stub `ollama.cmd`** on PATH, asserting exit 0, no
  "is not recognized" anywhere in the output, the fit table rendering, and **the BORDERLINE branch
  actually firing** - the branch that carried the bug.
- A static check for both shapes of `if`-in-expression-position across every `.ps1`.
- The fit classification exercised directly against `models.json`, asserting the thresholds separate
  models into more than one bucket and that something lands on BORDERLINE.
## 0.11.0 - 2026-08-06

**AD is now DAD - Design Document Aligned Development.** The old expansion ("AI Design-Doc-Driven
Development") was a mouthful that had to be explained every time, and the pronunciation gag was forced.
The new one says what the kit actually does: the design document is the contract, and every mode aligns
to it. No behavior changed in this release - only the name, and the compatibility needed to make the
rename safe for projects that already exist.

### Changed
- **Everything reads DAD**: prose, the dev-path placeholder (`...\AD-kit` -> `...\DAD-kit`), the package
  name (`DAD-kit-v<x>.zip`), the git identity close-unit commits under, and the scaffold commit message.
- **Scripts renamed**: `ad-doctor.ps1`/`.cmd` -> `dad-doctor.ps1`/`.cmd`, `ad-guard.ps1`/`.cmd` ->
  `dad-guard.ps1`/`.cmd`. The Stop hook in `settings.json` points at the new path; `install.ps1` rewrites
  it, so **re-running install is what moves an existing machine over**.
- **Marker files renamed**: `.ad-kit-version` -> `.dad-kit-version`, `.claude/.ad-verified` ->
  `.claude/.dad-verified`.
- **BMAADD is retired.** "BMAD on DAD" says the same thing without a second portmanteau to explain.

### Compatibility (projects scaffolded before the rename keep working)
- `dad-guard` recognizes `.ad-kit-version` as a project marker and honors a `.ad-verified` stamp. An
  unmigrated project must not fall silently OUTSIDE the guard - that is the failure the guard exists for.
- `dad-doctor` reads either version stamp.
- `upgrade-project` migrates both marker files in place (and re-stamps to the current kit version).
- **`scan-secrets` honors the pre-rename `AD-ALLOW-SECRET` marker, permanently.** That marker lives in
  YOUR source files; dropping it would silently stop suppressing lines someone already reviewed and
  cleared, and the scanner would start reporting them again as findings.

### Tests
66 cases (was 64). Two new: the old brand is gone from kit text - while `ad-hoc` survives untouched, which
a case-insensitive sweep would have mangled into `DAD-hoc` - and the legacy-compat constants are asserted
PRESENT so a future tidy-up cannot quietly delete them; plus `upgrade-project` migrating a pre-rename
project's markers, with the guard still recognizing that project beforehand. Lines that legitimately name
the old brand opt out with a `DAD-RENAME-OK` marker rather than the check guessing at intent.
## 0.10.0 - 2026-08-06

The first gate in this kit the model cannot skip.

A graded run (mediamotor_iiif, run002) produced **7,115 lines, 106 file edits, and ZERO shell calls**.
No build, no test, no `close-unit`, no commit - it wrote code, wrote tests for the code, then reasoned
in prose about whether those tests would pass, and ended with 47 dirty files. Nobody knew until the
transcript was read. The lesson from 0.9.x was "mechanical gates beat prose". This is the sequel:
**a gate the model has to choose to invoke is still prose.** `close-unit.ps1` verifies build, tests and
grade perfectly - if something calls it. Nothing did.

### Added
- **`dad-guard.ps1` / `.cmd` - the stop guard, wired by `install.ps1` as a Claude Code `Stop` hook.**
  The harness runs it at end of turn whatever the model decided, so it is the first gate that does not
  depend on the model's cooperation. Blocks the stop when uncommitted **code** files exist with no
  `.claude/.dad-verified` stamp newer than the newest edit, and names the three ways out: run
  `close-unit`, run the real build/test, or `dad-guard.cmd -Ack`. `close-unit.ps1` writes that stamp on a
  clean close, so a properly closed unit clears the guard by itself.
  - **A nag with teeth, not a wall.** The harness sets `stop_hook_active` on the retry pass and the guard
    allows it, so a broken model can still stop after being told and you can never be deadlocked. What it
    guarantees is that the failure is LOUD.
  - **Fails open** on everything unexpected: not a DAD project, no git, docs-only edits, git missing, its
    own errors. A guard that blocks on its own bugs would be worse than the problem it solves.
  - Docs, grades, `.claude/` and `bin`/`obj` are excluded - blocking on a `STATUS.md` edit would train
    everyone to ignore it.
- New requirement **R22** in `docs/DESIGN.md`.

### Changed
- **`/build` STOPS on a DRAFT design** instead of silently continuing "in PROTO mode" - which is what the
  failing run did before making 106 blind edits against an unfinished contract. R7 always said `/build`
  gates on LOCKED; the command now obeys it. Use `/proto` for greybox work.
- **`/build` proves the shell works before its first edit** by running `doc-stats.ps1` (Gate 3), and stops
  if it cannot. A `/build` that cannot reach a shell can only produce unverified code, and it will produce
  a great deal of it before anyone notices.
- **`grade-agent` has a search budget** (~25 calls) and may not repeat a query. One invocation burned
  1015+ identical `Search(pattern: "src/.../**/*")` calls before it was killed by hand.
- **`dad-doctor`** checks the Stop hook is wired and un-placeholdered, checks `dotnet`/`git` are permitted
  alongside `powershell`, reports whether a project currently has unverified code, and flags a project
  whose `.claude/settings.local.json` has accreted one-off `Bash(...)` approvals - the fingerprint of a
  session that spent its time answering permission prompts and then stopped using the shell. The failing
  run's project had ten, including `Bash(xargs cat)` and `Bash(</)`, and no `dotnet` or `git`.
- **`uninstall.ps1`** strips the Stop hook when there is no `.bak` to restore, so it cannot be left
  pointing at a deleted script and firing on every turn.

### Fixed
- `install.ps1` did not rewrite the dev-path placeholder in `settings.json` - which the new hook command
  lives in. It now does, **via the parsed object**: JSON escapes backslashes, so the on-disk form is
  `C:\\Projects\\...` and a raw-text replace of `C:\Projects\...` silently matches nothing. (The same trap
  install.ps1's own comment warns about for `.mcp.json`. I shipped it anyway; the test caught it.)
- Stale `use-model.cmd dev / plan / ...` line in the installer's closing output.

### Tests
64 cases (was 60), new `-- stop guard --` section: the guard blocks unverified code and clears after
`close-unit`; a fresh edit re-arms it; `-Ack` releases it; docs-only edits never block; it fails open on
non-DAD/no-git/missing directories; and it allows its own retry pass, which is the difference between a
guard and a deadlock.
## 0.9.9 - 2026-08-05

The fit math stops lying. `approxVramGb` was always weights-only, so three models advertised as
"fits 16 GB" actually spill once the 64K KV cache is allocated. And the planner is now `oss`.

### Changed
- **`plan` alias retired -> `oss` is THE planner** (`/design`, `/stories`, `/audit`). gpt-oss-20b is MoE
  (~A3.6B active), the most literal instruction-follower of the wired set, and cheaper to run than the
  dense alternative. Gemma 4 stays available as the optional dense generalist under the new alias
  **`gemma`**, honestly labelled: dense AND over the budget at 64K, so it partially offloads.
- **VRAM fit accounts for the KV cache.** `models.json` gained `assumeVramGb` (16) and `kvCacheGbAt64k`
  (3, at `OLLAMA_KV_CACHE_TYPE=q8_0`); a per-model `kvGb` overrides it if you measure a real one.
  `sync-models.ps1 -Report` replaced the `Fits16` column with `Weights` / `PlusKV` / `Fit`, and
  `dad-doctor` computes the same figure. Three states, not two:
  | state | rule | means |
  |---|---|---|
  | `fits GPU` | weights+kv+1.5 <= budget | GPU-resident, full speed |
  | `BORDERLINE` | weights+kv <= budget+1 | usually runs; expect partial offload, variable speed |
  | `offloads` | above that | spills to RAM by design (fine for MoE, slow for dense) |
  `dad-doctor` now emits a **WARN** on BORDERLINE with the fix (lower `numCtx` to 32768) instead of
  silently claiming a fit. Under this math `dev` and `oss` are BORDERLINE at 64K, not comfortable.

### Fixed
- README's version banner said **0.9.0** for eight releases. Now asserted against `VERSION` by a test.
- `CHEATSHEET.md` still routed planning to Gemma in three places, and one line read "/design design"
  (a leftover from the `/forge` rename). README's file table still named the retired `docs/COMMANDS.md`.

### Tests
60 cases (was 59): README-banner-matches-VERSION, plus `models.json` must carry `assumeVramGb` +
`kvCacheGbAt64k` and must not re-introduce a `plan` alias.
## 0.9.8 - 2026-08-05

Cosmetic but load-bearing: the pipeline now reads as what it does, with no glossary.
`/scaffold -> /design -> /stories -> /taskmap -> /build`

### Changed
- **Commands renamed** (all four were private metaphors; a model that half-remembers a metaphor guesses):
  | old | new |
  |---|---|
  | `/forge` | `/design` |
  | `/scribe` | `/stories` |
  | `/blueprint` | `/taskmap` |
  | `/librarian` | `/audit` |
  `/blueprint` existed only because `/tasks` is a Claude Code built-in; `/taskmap` is free and says what it
  is. All four new names verified free of built-in and BMAD collisions.
- **`planner-agent` -> `taskmap-agent`** - "architect" vs "planner" did not distinguish contract-pinning
  from task-sharding. Agent names that describe a ROLE well are kept: `scribe-agent` (writes STORIES) and
  `librarian-agent` (audits the doc set) stay, because the command is the verb and the agent is the actor.
- Audit owner tags follow: `[forge]` -> `[design]`, `[blueprint]` -> `[taskmap]`.

### Added
- **`install.ps1` deletes RETIRED names** from `~/.claude` before installing (`forge`, `scribe`,
  `blueprint`, `librarian`, `plan`, `planner-agent`), so upgrading does not leave the old command
  installed beside the new one for a model to invoke. No uninstall-first dance needed.
- **`.cmd` wrappers for every `.ps1`** - added `close-unit.cmd`, `doc-stats.cmd`, `install-hooks.cmd`,
  `ollama-tuning.cmd`. Commands/agents still invoke the `.ps1` via `powershell` (that is what the
  permission allow list covers); the wrappers are for running them by hand.
- Three drift tests: the install echo must match the real command list, no retired name may still ship,
  and every `.ps1` must have a `.cmd`.

## 0.9.7 - 2026-07-30

Closes the verification gap end to end: a story can no longer be closed unless the code builds, real tests
ran, and a real grade card exists.

### Added
- **`close-unit.ps1` verifies TESTS at story close.** It works out BEFORE mutating anything whether this
  close completes a story (last open task of that story, or a story id directly); if so it runs CLAUDE.md's
  `Test:` command and refuses on failure, on **zero tests**, or when it can find **no evidence any test ran**.
  "Build succeeded" with no test count is exactly the mediamotor no-op and is now a hard stop.
- **`doc-stats.ps1` reports ORPHAN TEST PROJECTS** - test `.csproj` files on disk that are absent from the
  `.sln`, the cause of that silent no-op. Verified against the real project: finds exactly its 6 orphans.
- **`/forge` ingests library API docs at design time.** For every third-party library the architecture
  commits to, it `web_search` + `ingest_url` the API reference into the corpus and records what it ingested.
  A dev-agent that cannot find a signature invents one (16 guessed Magick.NET calls); putting the real docs
  in the RAG at design time is the only reliable fix.

### Changed
- **`docs/COMMANDS.md` -> `docs/RECIPES.md`** (section: "Proven recipes"). "COMMANDS" collided
  conceptually with the kit's slash commands, so "check COMMANDS.md" was misreadable. `upgrade-project`
  migrates the old file and preserves its accumulated entries.

## 0.9.6 - 2026-07-30

A consistency audit of every command/agent file. Finding: instruction VOLUME is not the problem (~2% of a
64K window); the problems are contradictions between files and rules still enforced by prose.

### Fixed
- **The always-loaded project `CLAUDE.md` described the OLD `/build` order** ("requirements -> dev -> grade
  -> hygiene -> qa"). Every session read that first, then read `build.md` saying something different, and had
  to arbitrate. It now states the real order: per TASK dev -> qa -> close-unit; per STORY grade -> hygiene.
- **CHEATSHEET listed `generic` as a stack profile.** It is the always-installed base, not a profile - the
  profiles are `templates/<stack>/PROFILE.md` for dotnet|avalonia|python|embedded|unity.

### Added
- **`close-unit.ps1 -RequireGrade`** - the last soft gate is now mechanical. Closing a STORY with no grade
  card, a stub under 800 bytes, or no `## Grade history` FAILS. At task level it only warns (the card is
  written after roll-up, per /build's order). `/build` step 7 and `/grade` both pass `-RequireGrade`, so a
  story can no longer be closed ungraded - grading was the step that kept getting skipped.

## 0.9.5 - 2026-07-30

The mediamotor_iiif build results exposed the worst failure yet: **5 stories marked DONE, 6 tasks ticked and
4 checkpoint commits over a build failing with 21 errors and ZERO tests ever run** (all six test projects
existed on disk but none were in the .sln, so `dotnet test` was a silent no-op). The bookkeeping was
perfect; it was bookkeeping over unverified work, which is worse than none.

### Fixed
- **`close-unit.ps1` now VERIFIES THE BUILD before it ticks anything.** It reads the `Build:` command from
  CLAUDE.md (or `-BuildCommand`), runs it in a CHILD shell, and on failure prints the last 15 lines and
  exits non-zero having changed NOTHING - no tick, no roll-up, no commit. `-SkipVerify` overrides, with a
  warning that "done" then means nothing. If no build command is discoverable it warns loudly and proceeds.
- **qa-agent: a run that discovers ZERO tests is a FAIL**, not a pass - no test count, or "Build succeeded"
  with no results, means nothing was verified. It is also forbidden from writing its own test-report file
  (TEST_RESULTS.md / TEST_SUMMARY.md / *_RESULT.md were fabricated "all pass" summaries).
- **hygiene-agent: every test project on disk must be IN the solution.** Six orphaned test projects are what
  made every "tests pass" claim meaningless.
- **dev-agent: never invent a third-party API signature.** 16 of the 21 errors were guessed Magick.NET calls
  (a `ResizeStrategy` type that does not exist, `Crop` with the wrong arity, `int` where `ushort`/
  `Percentage` was required). Rule: `search_datasheets`, else `web_search` + `ingest_url` the official API
  docs into the corpus, else STOP - and build before reporting.
- **dotnet profile:** test projects must be in the .sln, plus the namespace-shadowing trap - a namespace
  ending in an SDK root name (`MyApp.Storage.Azure`) makes `Azure.ETag` resolve to your own sub-namespace
  (`CS0234`); use `global::Azure.ETag` or do not shadow the SDK root.

## 0.9.4 - 2026-07-30

### Fixed
- **`install.ps1` did not rewrite the dev-path placeholder in AGENT files** (only commands). 0.9.3 gave
  `librarian-agent` an absolute path to `doc-stats.ps1`, so after a folder-copy install it pointed at the
  authoring machine and the counter could not run - the STATUS miscount would have persisted. Agents now get
  the same rewrite as commands, with a test that fails if either folder ships an unrewritten placeholder.

## 0.9.3 - 2026-07-30

Fixes from the mediamotor_iiif run - the first run where `close-unit.ps1` actually executed (the 0.9.1
permission fix is validated) and the architect produced 18 numbered contracts with worked examples.

### Added
- **`/grade <unit>`** - there was NO user-invokable way to write a missing grade card, so a model invented
  `/grade`, a fictional `grade-agent --prompt ... > /dev/null` CLI, and a bash loop over agents. The command
  now exists, grades ONE unit, and gates the result.
- **`doc-stats.ps1`** - deterministic counts for `docs/STATUS.md`. The librarian hand-counted and wrote
  "Stories: 1/1  Tasks: 1/1" for a project with 13 stories (5 done) and 16 tasks (6 done). It must now RUN
  this and use the numbers verbatim; it also lists every DONE unit whose grade card is missing or a stub.

### Fixed
- **grade-agent produced nothing from a batch request** (40 tool uses, 54k tokens, zero files written). It
  now grades EXACTLY ONE unit per invocation and must write-then-verify before reporting - the same
  one-at-a-time rule that fixed /scribe and /blueprint.
- **/librarian handed the user homework instead of routing.** It now must spawn owner agents itself; only
  `[human]` findings come back. Explicitly: never tell the user to run an agent, never invent a CLI for one.
- **/forge did not fill CLAUDE.md** - Stack/Build/test were left as `<decided in /forge...>` placeholders, so
  dev and qa had no build or test command and improvised their own reporting files (TEST_RESULTS.md,
  TEST_SUMMARY.md, VariantProcessorTests_RESULT.md at the repo root). /forge now has a mechanical fill gate,
  and /build greps for the placeholders and REFUSES to start.
- **Scope-contamination check was crying wolf**: naming a class or file a task will create
  (`ResolverService.cs`) is implementation detail, not invented scope. The rule now targets capabilities,
  protocols, integrations and dependencies only.
- **planner-agent used absolute paths** (`D:\projects\...`) in `Touches:`; now repo-relative.
- **librarian regenerated STATUS four times** in one session (~155k tokens); now once per invocation.
- /forge also prompts to pin the toolchain for a clean machine (e.g. `global.json` for .NET).

## 0.9.2 - 2026-07-28

### Changed
- **Stack profiles are now FRAGMENTS** (`templates/<stack>/PROFILE.md`, was `CLAUDE.md`). They had drifted
  badly behind `templates/generic` - old `## Modes` wording, no Secrets, no Task-tool rule - and a file
  named CLAUDE.md that is not a complete CLAUDE.md invites mis-cribbing. Each now carries ONLY what
  `/forge` copies: Stack, Placeholder convention, Build/test, Human-in-loop, hygiene. Tests enforce that
  they contain no kit-owned sections.
- **No toolchain version is pinned in a profile.** `.NET 8` was hardcoded and stale. Profiles now tell the
  model to DETECT the installed toolchain (`dotnet --list-sdks` -> highest major -> `net<major>.0`) and
  record the choice in the design doc. C# version follows the TFM automatically - do not set LangVersion.
  Guidance added on LTS vs newest, and on targeting lower for published libraries. A test fails on any
  version number in a profile.
- **Unity is called out as the exception**: the editor caps the C#/.NET level, so never retarget or set
  LangVersion there.

### Added
- **Project-file hygiene convention** (the `PackageOutputPath` lesson, generalized): never put an absolute
  or machine-specific path in a build file - `PackageOutputPath`, `OutputPath`, `HintPath`, `Import`,
  local NuGet feeds. Use relative paths or `$(MSBuildThisFileDirectory)` / `$(SolutionDir)`. Plus the
  **clean-machine rule**: a fresh clone + the documented SDK must build and test with no manual setup.
- **hygiene-agent now scans for it** across `.csproj/.props/.targets/nuget.config`, `platformio.ini`,
  `CMakeLists.txt`, `pyproject.toml`, `package.json` and reports it `[mechanical]`.
- Test guarding the kit's own `net8.0` + `RollForward=LatestMajor` (deliberate: builds on 8+, runs on any
  8+ runtime, and the TFM is baked into every `.mcp.json` exe path).
- `scan-secrets` skips `_tempReference/` (reference drops, not kit source) but **announces the skip** and
  tells you how to scan it explicitly - a silent skip is how a real credential hides.

## 0.9.1 - 2026-07-28

Fixes found by the first full validation run on real hardware (LeanHash, qwen3-coder-next).

### Fixed
- **`close-unit.ps1` could never run.** `/build` and `/spec` invoke it via `powershell`, which was missing
  from `settings.json`'s permission allow list - so every call hit a permission prompt and was skipped.
  A whole `/build` session produced zero commits and zero ticked tasks because of it. Added
  `Bash(powershell:*)` + `Bash(pwsh:*)`, and a test that fails if any command invokes an executable the
  allow list does not permit.
- **Rubber-stamp grades passed the gate.** 135-byte cards reading "All acceptance criteria met" satisfied
  the old existence check. The gate now requires >=800 bytes plus `## Grade history`, `## Assessment` and
  `## Suggestions`; grade-agent is told a card with no cited `file:line` is a failed grade.
- **Whole-file regeneration let the planner invent a different project** (peer networking, a Prometheus
  endpoint, "[PR #n merged]" in a repo with no remote). `/blueprint` and planner-agent now shard ONE STORY
  AT A TIME, must trace every task to a real story id, may invent nothing absent from DESIGN/STORIES, may
  not claim unverifiable status, and must emit the exact task-block shape `close-unit.ps1` matches.
- **Contracts were unusable**: no worked examples, no `C1..Cn` ids to cite, and one contradicted the design
  doc's own storage layout. architect-agent now numbers contracts, self-checks that every one carries a
  concrete worked example, and must reconcile with (never silently contradict) the design.
- **librarian** now checks scope contamination FIRST - nouns in STORIES/TASKS that trace to nothing in
  DESIGN, and unverifiable claims - and flags stub grade cards.
- **`upgrade-project`** now untracks already-committed `bin/obj/docs/.index` (a `.gitignore` alone does not),
  so checkpoint commits stop carrying build-output noise.

## 0.9.0 - 2026-07-12

First versioned release. Feature-complete and self-tested; held below 1.0 until a full
`/forge -> /blueprint -> /build` run on real hardware is verified end to end.

### Core (R1-R10)
- Claude Code driven by local Ollama models, fully offline after setup (`settings.json` env redirect,
  no Anthropic account).
- One C# MCP server (`local-tools`): document RAG over per-project corpora with markdown-aware,
  heading-based chunking, atomic index writes, and an opt-in staleness refresh.
- Mode commands, a global agent team, one-command install/uninstall, GPU tuning.

### Design pipeline (R7, R11-R16)
- **Stack-agnostic scaffold + late architecture.** `/scaffold <general|experience>` creates the design doc
  as `Status: DRAFT`; the stack is decided late in `/forge`.
- **Layered docs**, each with exactly one writer: `DESIGN.md`/`TEDD.md` (contract, lockable) ->
  `STORIES.md` (`/scribe`) -> `TASKS.md` (`/blueprint`) -> `STATUS.md` (librarian-owned dashboard) plus
  `COMMANDS.md` (proven shell syntax) and `grades/` (report cards).
- **Contract layer** (`architect-agent`, `/forge contracts`): pins data formats, core-function semantics and
  invariants - each with a mandatory **worked example** that qa turns into the first unit test. Gates stop
  `/blueprint` from sharding, and `dev-agent` from implementing, an unpinned contract.
- `/librarian` cross-document audit with owner-tagged findings and git-recovery triage.

### Reliability (R13, R18-R20)
- **Git safety net**: scaffold initializes a repo; every passing unit is a checkpoint; a mangled file is
  restored from git, never hand-reconstructed.
- **Loop cost discipline**: per task only dev + qa run (was 5-8 subagent spawns), bookkeeping is the
  deterministic `close-unit.ps1` (tick, story roll-up, reindex, commit, verify), and grade + hygiene run at
  the story boundary.
- **The kit tests itself**: `test-kit.ps1` (44 cases) + CI on Windows - the validation gate, covering static
  hygiene, inventory/collision consistency, the secret scanner, and fixture runs of scaffold/upgrade/close-unit.
- **Secret hygiene**: `scan-secrets.ps1` (never prints matched values) installed as each project's
  pre-commit hook, standard allowlist markers honored, and a kit-owned `## Secrets` section in project
  CLAUDE.md - because `docs/` becomes a plaintext search index.

### Operations (R21)
- **`models.json`** is the single source of truth for models; `sync-models.ps1` generates the `-cc`
  Modelfiles and builds the variants. Adding a model is one JSON entry.
- **`dad-doctor.ps1`**: read-only readiness check for prerequisites, Ollama + declared models, the server's
  live MCP tool list, the global install, and a project's wiring.
- **`upgrade-project.ps1`**: retrofits an existing project to the current kit, refreshing kit-owned
  CLAUDE.md sections while preserving your Stack/Build/test.

### Sensors (R17)
- Images in `docs/` are captioned and audio optionally transcribed at index time (cached), so a whiteboard
  photo becomes searchable design context. `describe_image`, `detect_objects` (ONNX), `transcribe_audio`.
- Optional push-to-talk voice loop (`voice.py`, uv + faster-whisper + headless `claude -p`).

### Known limitations
- Windows-only scripting (the C# server itself is portable).
- `detect_objects` is compile-verified but not inference-verified; bring your own ONNX model.
- Quality depends on the local model: contract-pinning and `/blueprint` want the strongest model available.
