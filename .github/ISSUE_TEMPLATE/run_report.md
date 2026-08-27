---
name: Run report
about: You ran DAD-kit on a real project and something went sideways (or went well). This is the most valuable report you can file.
title: "[run] "
labels: run-report
---

<!-- The kit is hardened failure by failure. A transcript of a real run - especially a bad one - is worth
     more than a feature request. Redact any secrets or client detail before pasting. -->

## What you were doing

- Command / mode when it happened (e.g. `/build`, `/stories`, `/taskmap`):
- Project type / stack (e.g. ASP.NET Core, Python, research site):
- Was this a fresh scaffold or an existing project?

## What happened

<!-- The behavior. If it spiralled, roughly how many tool calls before you stopped it. If it looped one
     command, paste that command. If a gate fired (or should have and did not), say which. -->

## Environment

- DAD-kit version (`dad doctor` prints it, or see VERSION):
- Model + alias used (e.g. `next` / qwen3-coder-next, `oss` / gpt-oss-20b):
- GPU + VRAM:
- Ollama version:
- Windows version:
- `dad doctor` output (paste the summary line: N fail / N warn):

## Transcript

<!-- Paste the relevant slice, or attach the exported run. The collapsed "agent(...) +N tool uses" lines
     are exactly what we need to see. -->

## What the kit's own tools said

<!-- If you can, paste: `dad doc-stats -Findings`. It computes the true project state and often shows the
     problem faster than the transcript. -->

## Anything else

<!-- Did a watchdog / loop guard catch it? Did you have to kill it by hand? How long did it run? -->
