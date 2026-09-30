# Story S11 - [SPIKE] Should high-stakes verification run as a separate process? (R32) : report card

**Current grade: A-**  (as of 2026-09-30, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-30        | A-    | first card for S11; write-up, R32 text, T11.1/T11.2 and a B/C-build grep READ; no prior card on disk |

## Assessment (this iteration)
Read: docs/STORIES.md:421-509 (whole S11 block), docs/DESIGN.md:252-273 (R32 in full), docs/TASKS.md:1394-1468 (T11.1, T11.2), docs/TASKS.md:1864-1871 note (grep hit). Not run: suite (assessor is read-only). No source code exists for this story, so none was read.

- Correctness: good. The spike delivers what Goal/Behavior ask: a cited write-up weighing structural gain vs two-session cost (STORIES.md:485-492), citing R32 and the Kapitan/Auditor HANDOFF -> EVIDENCE -> VERDICT bus (469-474).
- Draft checked against R32 (T11.1): verified claim by claim against DESIGN.md:252-273. "Three consecutive runs died inside a subagent" with 920/947/1023 calls (STORIES.md:465-466 vs DESIGN 253-255) matches. "Eleven graded runs ... zero loops" (458 vs DESIGN 255-256) matches, and the draft correctly adds that these are MAIN-loop runs, not subagent evidence (459-460), which is the right non-overstatement. R32(a) hook does not fire (463 vs 258), R32(b) tools: frontmatter (464 vs 261), R32(c) transcript (464-465 vs 263), "nothing can interrupt a spawn" (465 vs 270), 5 and 9 call successes (458-459 vs 265-266), one-agent-per-unit with retry limit of one (461-462 vs 266-269): all faithful. Claims R32 and S11 Context do not support are marked "(unverified - would need measurement)" at 457-458, 467-468, 476-479, 483-484, 487, citing R37(c) as precedent (477-478). No overstatement found.
- Recommendation deferred to the human (T11.2 / AC2): the pre-decision draft names A, B and C and states "This write-up does not pick for you; no build work follows from S11 until the human answers" (493-496). No option is labelled recommended; the "argues toward a hybrid" framing (490) is allowed because the same section defers the pick. Then the human decided (497-509: Option A plus computed checks), which is recorded as a [human] decision with a date, not as the agent's pick. AC2 text was updated to say so (450-451). This is the correct sequence for a spike.
- No build work toward B/C: the Decision states "Options B and C are NOT built" (497-498) and gives a revisit trigger (a MEASURED same-session failure recurring after S18, and measure first whether a second `claude` process's own hooks fire, 508-509). TASKS.md:1864-1871 records S11 as deliberately having no code tasks. Grep of STORIES.md and TASKS.md for HANDOFF|Kapitan|Option B|Option C|second Claude Code returned 11 and 13 hits; I did not read every hit, but the sampled ones are S11's own text and the S18/S15 Refs to S11's Decision (TASKS.md:1823, 1837), which build computed checks (R24), not a second process. Confidence high, not exhaustive.
- Design: no contract touched; no DESIGN prose edited (DESIGN is LOCKED). Follow-up work is routed to S18 under R24/R32, consistent with R24's "never accept an assertion a script can settle".
- Acceptance: AC1 and AC2 both ticked and supported by the cited text. Status marker is `DONE closed:close-unit` (421), so the close was done by the tool, as T11.2 step 4 required.
- Quality: decision evidence is concrete (about 35 spawns, longest 67 calls, three named self-report failures at 501-507). Two of those failure claims are the orchestrator's own run observations, not reproducible from a committed artifact (S9 dad-guard.ps1:168 line is checkable; the S10 hygiene/doc-stats claim is not linked to a file). Blemishes: line 454 Dev notes still says "still unresolved: nobody has picked option A, B or C yet", which now contradicts the Decision at 497; line 493-494 has a stray colon where a semicolon belongs ("for all agents: (B)").
- Hygiene: docs-only change; ASCII-clean as far as read. No manifests or dependencies involved.
- Verification mode: no AC touches machine state (env vars, models, files outside the project). Nothing live-run; all verification was code/doc-review.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [mechanical] Fix the stale sentence at docs/STORIES.md:454 ("still unresolved: nobody has picked option A, B or C yet") to say the human decided A on 2026-09-30 (see Decision), and change the colon to a semicolon at STORIES.md:494. STORIES.md is editable while DESIGN is locked.
2. [dev] When S18 lands, add a test-kit assertion or grep case that no task or story references a HANDOFF/EVIDENCE/VERDICT bus or a second Claude Code session as a build item, so "B/C not built" stays enforced rather than a one-time grep (the T11.2 grep was a manual check).
3. [human] Confirm that the measured evidence at STORIES.md:499-507 (35 spawns, three self-report failures) is acceptable as recorded from the session with no linked artifact, or ask for the S10 hygiene/doc-stats discrepancy to be pointed at a file or commit.
