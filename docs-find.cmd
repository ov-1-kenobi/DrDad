@echo off
REM docs-find.cmd - search this project's indexed docs FROM THE SHELL (same corpus as search_datasheets).
REM Across nine graded runs the MCP tool was never called once while kit scripts were called constantly,
REM so the corpus needs a shell door. Works even when the MCP server is not connected.
REM   docs-find.cmd "what does C9 say about tile sizes"
REM   docs-find.cmd "TableClient upsert" -Top 8
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0docs-find.ps1" %*
