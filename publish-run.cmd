@echo off
REM publish-run.cmd - copy a session transcript + a computed state snapshot into a proving-ground repo's
REM runs\ folder, SECRET-SCANNED first, and commit locally (never pushes).
REM   dad publish-run -ProjectDir C:\src\cms3 -Transcript C:\...\run.txt -Label s2-auth
REM   dad publish-run -Transcript run.txt -RunsRepo C:\src\dad-kit-runs
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish-run.ps1" %*