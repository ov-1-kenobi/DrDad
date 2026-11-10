# Tier 2 proposals - DrDad kit, 2026-11-09

Status: WAITING FOR YOUR ANSWER. Nothing in this file is implemented.

Each item changes how the kit behaves for every project, so each one needs your choice first. For
each: the evidence I found in the GDN project (read-only), two or three options with their
trade-off, and my recommendation. To answer, reply with the item number and option letter
(for example "5B, 6A, 7B ..."), or with changes.

Note on sources: these proposals were first written from evidence I measured in GDN myself,
because DRDAD-FEEDBACK-2026-11-09.md was not on disk at the time. The file was supplied later
(2026-11-09, `_tmp/`). I compared each item with it. Where the feedback asks for something my
options did not cover, the item now ends with a line starting "Feedback file:". Its counts differ
a little from mine (for example 7 A / 26 A- / 7 B+ against my 6 / 27 / 7); both are approximate.

---

## 5. Grader rigor and grade calibration

Evidence: of GDN's 41 grade cards, the 40 whose history row I could parse are 6 A, 27 A-, 7 B+. Nothing below B+ across a
project where story closes failed their tests repeatedly. grades/S55_GRADE.md records an A- and
says in its own history row "code-review only, no build/test run by the grader"; the gate log
shows the S55 story close failing its tests twice around that grade (2026-11-05 02:39 and 02:50).
The grader has no shell, so it cannot see a red suite.

- A. Feed the grader facts it cannot fake. close-unit writes a small machine-made "evidence" block
  (test exit code and count, ratchet result, number of blocked closes for the story from the gate
  log, open doc-stats findings) and the grade-agent must copy it into the card. A script-checked
  cap applies: a story whose close was blocked for failing tests, or with an open finding, cannot
  be graded above B. Trade-off: mechanical and cheap, hard to argue with; but it calibrates only
  the top of the scale, not the grader's judgement.
- B. A plus a fixed rubric with point deductions per axis (each unmet acceptance criterion -1
  letter step, each contract divergence caps at C, and so on), and the card must show the sum.
  Trade-off: grades become comparable across stories and models; costs a longer agent prompt and
  local models follow long rubrics poorly.
- C. A second, independent grader on a different model for a sample of stories, with a WARN when
  the two differ by more than one step. Trade-off: best signal on calibration; doubles grading
  cost and needs a second model loaded.

Recommendation: A now. It removes the main cause (the grader cannot see failures) with a script,
which is where this kit's gates have worked. Consider B after one project has run with A.

Feedback file: it asks for the same thing as A ("require each card to quote close-unit's test
result"), adds that 28 of 40 cards say the grader ran neither build nor tests, and that cards stop
at S59 while later stories are DONE. The second point is partly closed by the Tier 1 fix for issue
14 (a rolled-up story now blocks other stories until its story-level close, which /build runs
with -RequireGrade). Citation checking at story close already exists (-RequireGrade).

## 6. Turning repeated grader suggestions into tasks

Evidence: the same suggestion recurs across cards and is never actioned, for example "Tick the
acceptance boxes in docs/STORIES.md" on three cards (S23, S31 and one more). /retro exists to catch
this but it is a manual command, and I found no commit in GDN's history that records a /retro run.

- A. grade-trends gets a mode that lists suggestions seen in 3 or more cards, and close-unit prints
  that list as a WARN at each story close ("3 recurring suggestions - run /retro"). Trade-off:
  tiny change, keeps the human in charge; it is still only a nudge.
- B. A plus automatic staging: at story close, each recurring [dev] or [mechanical] suggestion not
  already tracked is appended to TASKS.md as an unticked task under a standing "Sx-debt" story,
  through the taskmap-agent's format. Trade-off: nothing is lost; but it grows TASKS.md
  mechanically (GDN's is already 3.6 MB) and fuzzy matching of "the same suggestion" will make
  duplicates.
- C. Make /retro a gate: close-unit refuses the 6th story close since the last retro commit.
  Trade-off: guarantees the loop runs; adds a hard stop that an unattended run cannot clear.

Recommendation: A, plus one piece of B: only [human]-approved items become tasks, at /retro time.
Automatic task creation from fuzzy text matching will add noise faster than it removes debt.

## 7. A work-in-progress limit while human gates are open

Evidence: docs/STATUS.md lists more than a dozen open human gates (T30.17, T31.11, T33.5, T34.6, T36.8,
T37.9, T40.11 ...) and says 12 stories are "BUILT but unclosed/ungraded until human live gates are
ticked" (S36-S38, S40-S44, S48, S50-S52). Meanwhile the backlog grew from 54 to 109 stories and
work moved on to S104.

- A. Soft limit: doc-stats counts stories that are "built but waiting on a [human] task" and
  /build prints a WARN above a threshold (default 3). Trade-off: no run is ever blocked; a warning
  was already visible in STATUS.md and did not change behavior.
- B. Hard limit with a human override: /build Gate (and close-unit, for a task that starts a NEW
  story) refuses when more than N stories are waiting on human gates; N lives in CLAUDE.md
  (default 3) and you can raise it. Trade-off: forces the smoke tests to happen while the code is
  fresh; an overnight run stops early when the limit is hit, by design.
- C. Hard limit per epic only: no new epic may start while the previous epic has open human
  gates. Trade-off: coarser, fewer stops; still lets a dozen stories pile up inside one epic.

Recommendation: B with N=3 in CLAUDE.md. The pile-up is the expensive failure, and the limit is a
number you control.

Feedback file: it places the limit one step earlier - block `/design` and `/stories` from
EXPANDING the backlog while more than N human gates are open - and asks for the open gates to be
batched into one human checklist. I agree that is the better place: option B should gate /design
(new epics) and /stories (new stories) as well as /build, and doc-stats should print the open
[human] tasks as one checklist. Say "7B+" to choose that.

## 8. Checking new epics against the design's Goal

Evidence: GDN went from 54 to 109 stories in ten days; DESIGN.md is 1.24 MB with a "Supported
platforms and roadmap" section added by amendment. New work (LAN shares, an app framework,
neighbors) entered through design passes, and the kit's /design command has no step that compares
a new epic with the Goal section.

- A. /design asks one question and records the answer: when an epic is added, the agent must
  quote the Goal sentence it serves and you confirm; the epic line gets "Serves: <goal clause>"
  and doc-stats -Findings flags an epic without it. Trade-off: cheap, makes scope growth a visible
  decision; relies on you reading the question.
- B. A plus an explicit "Non-goals / deferred" list in DESIGN: an epic that matches no Goal clause
  must either amend the Goal (a dated human decision) or go to the deferred list. Trade-off:
  cleaner record of why scope grew; one more DESIGN section to maintain.
- C. A scripted budget: the number of epics may not grow by more than K per lock cycle without a
  flag. Trade-off: fully mechanical; a count is a poor proxy for scope.

Recommendation: B. The gap in GDN is not that scope grew but that nothing recorded it as a choice.

## 9. Requiring an end-to-end path before a story's tasks count as done

Evidence: STATUS.md describes stories as "BUILT except their human smoke checks" and E7 as built
but unclosed; fixes found only by the full suite ("three failures found by the S92 story-close
suite") show tasks closing green in isolation.

- A. Taskmap rule: every story must contain exactly one task tagged [e2e] whose acceptance runs
  the real entry point (CLI command, HTTP route, UI path); close-unit refuses to roll the story
  up to DONE if no [e2e] task exists or it is unticked. Trade-off: mechanical and simple; old task
  maps have no tag, so this must only apply to stories sharded after the upgrade.
- B. A, and the [e2e] task must be FIRST in the story's build order as a failing walking skeleton.
  Trade-off: catches integration problems earliest; a failing test parked for several tasks
  conflicts with "the suite is green at every close", so it needs a skip convention.
- C. No tag; instead the story close runs a "Smoke:" command from CLAUDE.md in addition to
  "Test:". Trade-off: one command for the whole project is easy to adopt; it does not prove the
  NEW story is on the path.

Recommendation: A, applied only to stories that have no ticked tasks at upgrade time.

Feedback file: it also asks that /build finish one story before starting the next (on 2026-11-09
tasks from about nine stories were interleaved) and that a command whose core path is a stub is
not registered. The first is partly enforced by the Tier 1 fix for issue 14; a stricter rule
("no task of story B while story A has open non-human tasks") would be a further option, 9D. The
second is a project code rule: it fits as a line in the grade rubric and in dev-agent, not a gate.

## 11. Compacting DESIGN/TASKS and consolidating security reviews

Evidence: docs/DESIGN.md 1.24 MB, docs/TASKS.md 3.64 MB, docs/STORIES.md 0.94 MB. The
"## Security decisions" section alone runs from line 44 to line 1245 because each incremental
security-agent pass appended a block. Every agent prompt says "read the design doc directly",
which no longer fits in a context window.

- A. Archive on close: when a story closes, close-unit moves its ticked task blocks from TASKS.md
  to docs/archive/TASKS-<epic>.md, leaving a one-line stub (id, title, commit). The ratchet counts
  stubs plus archive so totals do not "shrink". Security passes write to one table (decision,
  source, date, status) and a new pass REPLACES superseded rows instead of appending.
  Trade-off: the working files stay small with no information lost; the archive must be excluded
  from, or separately handled by, the index and the ratchet, which touches several scripts.
- B. A manual "/audit compact" command that does the same on request. Trade-off: no surprise file
  moves; in GDN nobody ran the optional commands.
- C. Leave the files; change the agents to never read them whole (search only). Trade-off: no
  file churn; the kit's own measurements show agents fail when search is their only door.

Recommendation: A for TASKS.md and for the security table; DESIGN prose stays manual (/design
proposes a compaction diff while DRAFT and you approve). DESIGN is the contract, so a script
should not rewrite it.

## 13. Shared test fixtures; stopping qa-agent from mirroring dev-agent tests

Evidence: GDN has more than 10,000 test markers. Commit dc557ef (T80.3) adds a 163-line reader
with a 330-line test file and a second, 381-line "Adversarial" test file for the same class. Two
commits on 2026-11-09 fix tests that "failed under the parallel story-close suite" (timing and
process-wide memory assertions), and a third fixes three failures found only by a story-close run.

- A. Prompt change only: qa-agent must first list the dev-agent's tests for the unit and may only
  add tests for acceptance criteria or contract examples that are NOT already covered; it must
  reuse fixtures under a named folder (tests/**/Fixtures) and add to them rather than build its
  own. Trade-off: zero tooling; prompts alone have a poor record in this kit.
- B. A plus a script check in close-unit: WARN when a close adds a new test file whose test-method
  names overlap an existing file for the same class by more than half, and WARN when the ratio of
  added test lines to added source lines is above a limit (for example 4:1). Trade-off: makes the
  duplication visible at the moment it happens; heuristics will sometimes be wrong, so WARN only.
- C. Split roles: dev-agent writes NO tests, qa-agent writes all of them. Trade-off: removes
  mirroring by construction; dev-agent loses its fast feedback loop and task closes get slower.

Recommendation: B. Note this pushes against the ratchet (which rewards test count), so the WARN
text must say that fewer, shared tests are the goal.

## 16 (pruning part). Pruning broad permission allow-rules

Evidence: GDN's .claude/settings.local.json holds dozens of one-off rules plus broad ones:
"Bash(wsl *)", "Bash(curl *)", "Bash(cmd.exe *)", "Read(//d//**)". dad-doctor already WARNs about
one-off clutter but says nothing about breadth. (The warning for an elevated shell, the other
half of this issue, is implemented in Tier 1.)

- A. Report only: dad-doctor lists the broad rules (a wildcard directly after an interpreter or
  network tool: cmd, powershell, wsl, bash, curl, python, a whole-drive Read) as WARN with the
  exact lines. Trade-off: safe; you still prune by hand.
- B. A plus "dad doctor -PrunePermissions": shows the proposed removals, asks y/n, writes a
  backup, removes one-off and broad rules. Never run by an agent (it prompts). Trade-off: one
  command to fix; removing a rule a run depends on means more permission prompts next session.
- C. Automatic prune at story close. Trade-off: always clean; silently changing permissions under
  a running session is the kind of surprise this kit avoids elsewhere.

Recommendation: B.

## 17. Enforcing human source tiering

Evidence: docs/SOURCES.md pass notes say sources were "all labelled primary by the caller's
instruction, the human re-tiers", and other passes left every tier unknown. The kit's rule is that
only the human tiers a source; today nothing checks who wrote the tier, and source-stats only
WARNs on unknown.

- A. Lock gate: /design refuses to set Status: LOCKED while any source CITED in DESIGN has tier
  unknown (source-stats already computes this). Trade-off: small; does not stop an agent writing
  "primary" itself.
- B. A plus provenance: tiers are set only through "dad source-tier <id> primary|secondary", which
  prompts on the console and writes a dated "tiered-by: human" cell; source-stats FAILs a row
  whose tier changed in a commit made by the kit identity or without that stamp. Trade-off: closes
  the hole where the agent tiers; adds a column to SOURCES.md (needs an upgrade step) and a little
  friction per source.
- C. Keep tiers out of the agent's reach: move them to a separate file that the guard hook blocks
  agents from editing. Trade-off: strongest; splits the ledger in two and complicates citations.

Recommendation: B, with the lock gate from A.

Feedback file: it reports 317 of 334 rows tiered `primary` (deepwiki.com among them), and two
mechanical defects beside the tiering question: the SOURCES.md header and research-agent say
captures live in `docs/sources/`, while `ingest_url` writes them to `docs/web/` (Rag.cs WebDir);
and GDN has 419 captured pages, about 35 MB, committed. The path mismatch is a plain bug I can fix
without a policy decision - say "17 path" to have it done. Whether captured pages belong in git
is yours to decide (keep, gitignore `docs/web/`, or keep only the ledger).

## Also in the feedback file (not in the 18)

- Loop-guard fired 63 times on read-only exploration (25 reads in a row): make the threshold
  configurable per agent. Small and mechanical; not done, because it was not in the Tier 1 list.
- The project CLAUDE.md "Placeholder convention" named interfaces GDN never created. That text
  comes from the stack profile example that /design copies in. Option: /design writes the section
  from the design's own Domain model, and doc-stats flags a type named in CLAUDE.md that is absent
  from the API surface.
- No README and no CI in the generated project: the scaffold could add a minimal README and a CI
  workflow that runs the Build and Test lines.
- One thing I found while checking issue 2: when the last task of a story closes, the gate log
  records only "clean close: T73.8" - nothing in the log says story S73 rolled up. That is why the
  feedback reads S73's last entry as a failed close. The roll-up was in fact a passing close 51
  minutes later. Adding "(story S73 -> DONE)" to that log line is a one-line change; not done
  yet, to keep the deployed tools stable.
