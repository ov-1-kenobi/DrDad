@echo off
REM tidy.cmd - clear project-root junk and empty the _tmp scratch folder. Lists by default; -Fix removes.
REM   dad tidy            list what would be removed
REM   dad tidy -Fix       remove the junk and empty _tmp\
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tidy.ps1" %*