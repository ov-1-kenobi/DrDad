@echo off
REM api-surface.cmd - regenerate docs\API-SURFACE.md: exact public signatures of the project's own
REM assemblies AND of the NuGet packages it references, read from the compiled DLLs. Needs a build first.
REM   api-surface.cmd                          current folder
REM   api-surface.cmd -ProjectDir C:\src\App
REM   api-surface.cmd -Lookup TableClient      just print the signatures for one type/member
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0api-surface.ps1" %*
