@echo off
REM data-stats.cmd - the DATASET integrity gate (counterpart to source-stats).
REM Declare datasets in docs\DATASETS.md; this checks the real files against the declaration.
REM   dad data-stats                 all datasets, exit 1 on any FAIL
REM   dad data-stats -Dataset D001
REM   dad data-stats -Json
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0data-stats.ps1" %*