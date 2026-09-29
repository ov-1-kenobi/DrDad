@echo off
REM dad-guard-copilot.cmd - the Stop hook ADAPTER for GitHub Copilot CLI.
REM Copilot CLI ignores exit code 2 (and discards stdout with it), so dad-guard.ps1's verdict has to be
REM re-emitted as JSON with exit 0. This wrapper does that; dad-guard.ps1 still makes the decision.
REM Wired automatically by install.cmd -CopilotCli (%USERPROFILE%\.copilot\hooks\dad.json).
REM   dad-guard-copilot.cmd -Check       would it block right now? (passthrough to dad-guard.ps1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dad-guard-copilot.ps1" %*
