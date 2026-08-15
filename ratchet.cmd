@echo off
REM ratchet.cmd - refuse to let the project's verification surface shrink: tests, contracts,
REM requirements, backlog totals, sources, grade-card bytes, and CLAUDE.md's Build/Test commands.
REM A gate that only asks "is X OK now?" is satisfied by DELETING X. This asks "did X shrink?"
REM   ratchet.cmd                     compare against the baseline (exit 1 on any drop)
REM   ratchet.cmd -Update             record the current counts as the baseline
REM   ratchet.cmd -Json
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ratchet.ps1" %*
