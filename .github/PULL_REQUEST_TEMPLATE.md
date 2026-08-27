<!-- Thanks for contributing. The kit lives or dies by its gate, so the checklist is not a formality. -->

## What this changes

<!-- One or two sentences. If it fixes a real run, name the incident: "on a run, X happened." -->

## The incident behind it

<!-- What went wrong that motivated this? A change that traces to a measured failure is the norm here. -->

## Checklist

- [ ] Added or updated a `Test-Case` in `test-kit.ps1` that FAILS without this change.
- [ ] `.\test-kit.ps1` prints `0 failed` (run the full suite; `-SkipBuild` if you lack the .NET SDK, but
      say so).
- [ ] Prefers a script gate to a prose instruction where a check can be computed.
- [ ] Fails loudly on the thing it checks; fails open on its own errors.
- [ ] ASCII only in `.ps1` / `.cmd` / `.md` / `.json` (no em-dashes, smart quotes, arrows, emoji).
- [ ] `CHANGELOG.md` updated; `VERSION` bumped to match if user-visible.
- [ ] Does not weaken machine security, redistribute model weights, or bundle Claude Code.

## Anything reviewers should know

<!-- Trade-offs, follow-ups, or things you were unsure about. Honesty about what you did NOT verify is
     welcome and in keeping with the project. -->
