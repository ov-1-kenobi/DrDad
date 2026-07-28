---
description: Run the hygiene-agent - format/lint, keep project files in sync with disk, fix dependency drift, re-build.
argument-hint: [optional scope/area; empty = whole project]
---
Run the **hygiene-agent** on this project (scope: **$ARGUMENTS**, or the whole project if empty).
Spawn it via the **Task tool** (subagent_type: "hygiene-agent") - it is an AGENT, not a skill.

Using CLAUDE.md's lint/format/build/dependency commands, it: formats + lints, checks that project files
(.sln/.csproj/manifests/imports) stay in sync with the files on disk, ensures packages are
declared/restored/used correctly, then re-builds to confirm nothing broke.

Have it FIX the mechanical issues directly and report anything that needs my decision (never delete deps on
its own). Best run on `dev` (Devstral) after a `/spec` or `/build`, or any time things feel drifty.

If you scope it to a story (e.g. `/tidy S3`) and `grades/S3_GRADE.md` exists, the hygiene-agent also applies
that report card's `[mechanical]` suggestions as part of the pass.
