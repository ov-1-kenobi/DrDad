@echo off
REM sync-models.cmd - reconcile Ollama with models.json (pull bases, build the -cc variants).
REM   sync-models.cmd                 pull autoPull bases + build every variant whose base is present
REM   sync-models.cmd -All            also pull the big optional bases (large downloads)
REM   sync-models.cmd -Only coder     just one alias
REM   sync-models.cmd -Report         report only, change nothing
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-models.ps1" %*
