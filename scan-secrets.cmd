@echo off
REM scan-secrets.cmd - scan a folder for credentials before they reach git or the RAG index.
REM   scan-secrets.cmd                  scan the current folder
REM   scan-secrets.cmd -Path C:\src\App scan a folder
REM   scan-secrets.cmd -Staged          scan git-staged files (what the pre-commit hook runs)
REM Never prints the matched value - only file:line, the pattern name, and a fingerprint.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scan-secrets.ps1" %*
