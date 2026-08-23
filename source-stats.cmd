@echo off
REM source-stats.cmd - citation-integrity gate for /research: do the design doc's [Snnn] citations
REM resolve to real, assessed sources? Exit 1 on any FAIL.
REM   source-stats.cmd
REM   source-stats.cmd -ProjectDir C:\src\App
REM   source-stats.cmd -StaleDays 180 -Json
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0source-stats.ps1" %*
