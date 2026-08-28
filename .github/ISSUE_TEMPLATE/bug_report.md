---
name: Bug report
about: A kit script, gate, command, or the installer misbehaves
title: "[bug] "
labels: bug
---

<!-- For a problem during an agentic RUN (a model spiralling, a bad task map, a gate that should have
     fired), please use the Run report template instead - it captures the right context. Use this one for a
     defect in the kit's own tooling. -->

## What is wrong

<!-- Which script/command/gate, and what it did vs. what you expected. -->

## Reproduce

1.
2.
3.

## Expected

## Actual

<!-- Paste the exact output. Kit scripts fail loudly on purpose; the message usually names the cause. -->

## Environment

- DrDad version:
- `dad doctor` summary line:
- Windows + PowerShell version (`$PSVersionTable.PSVersion`):
- .NET SDK version (`dotnet --version`), if the C# server is involved:

## Did the test suite catch it?

<!-- Run `.\test-kit.ps1 -SkipBuild`. If it stays green while the bug reproduces, that gap is itself part of
     the report - the fix will need a new Test-Case. -->
