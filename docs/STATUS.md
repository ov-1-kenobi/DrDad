# Status - DrDad

## Snapshot
- As of: 2026-09-22  (session model: librarian audit)
- DESIGN: LOCKED   Stories: 7/7   Tasks: 16/16

## Done (recent, newest first)
- S7 (T7.1, T7.2, T7.3): ask-time scope pricing - C1c pricing sentences added to stories.md's expand loop
  and design.md's requirement/epic-capture step; test-kit.ps1 Test-Case added.  (grade B+)
- S6 (T6.1, T6.2): walking-skeleton ratchet - [ratchet] WARN finding added to doc-stats.ps1 -Findings per
  the pinned C1a/C1b formula; test-kit.ps1 Test-Case covers all 5 worked scenarios.  (grade A)
- S5 (T5.1): renamed packaged output DAD-kit -> DrDad (package-kit.ps1 + test assertion + README note).
- S4 (T4.1-T4.3): R35 sandboxing/consent convention written into dev-agent.md/qa-agent.md, a test-kit.ps1
  guard-conditional check, and grade-agent's verification-mode recording requirement.
- S1-S3: safe uninstall, local web-tools steering convention, avalonia template - all DONE pre-migration.

## In progress / next ready
- NEXT: none - all 7 stories / 16 tasks are DONE.

## Issues & blockers (dated; clear them when resolved)
- 2026-09-22: Story S7 AC3 (re-running install.cmd so %USERPROFILE%\.claude\commands\ picks up T7.1/T7.2's
  stories.md/design.md edits) is deliberately DEFERRED pending the human's explicit consent, per R35(b) -
  it mutates state outside this project. Tracked in STORIES.md's Story S7 <!-- Implemented: ... --> note
  and in grades\S7_GRADE.md. Clears once install.cmd is run live and the note is updated.

## Notes for the next session
- doc-stats.ps1 -Findings reports one generated finding worth a human look: the NOT-REQUIRED security
  review waiver on a doc that mentions auth/token/session vocabulary (R31's own rule keeps that class
  REQUIRED by default) - confirm the waiver still holds or flip it via /design.
- All planning mass is now proven out (7/7 stories, 16/16 tasks) - the R36 walking-skeleton ratchet
  ([ratchet] in doc-stats.ps1) and the C1c pricing-ask sentences (S7) are both live for the NEXT round of
  scope growth.
