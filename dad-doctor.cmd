@echo off
REM dad-doctor.cmd - readiness check: prerequisites, Ollama + models, the kit, the global install.
REM Read-only - it diagnoses and prints the fix commands; it changes nothing.
REM   dad-doctor.cmd                            check the stack
REM   dad-doctor.cmd -ProjectDir C:\src\MyApp   also check that project's wiring
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dad-doctor.ps1" %*
