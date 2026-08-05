@echo off
REM doc-stats.cmd - print the REAL counts for docs\STATUS.md (stories/tasks done, next task,
REM missing grade cards, orphan test projects). Use these numbers verbatim - do not estimate.
REM   doc-stats.cmd                     current folder
REM   doc-stats.cmd -ProjectDir C:\src\App
REM   doc-stats.cmd -Json               machine-readable
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0doc-stats.ps1" %*
