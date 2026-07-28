@echo off
REM reindex.cmd <docsDir> - rebuild the RAG index for a project's docs folder.
REM One-off use, or point a Windows Scheduled Task at this line. No pause (so scheduling won't hang).
REM Example task action:  reindex.cmd "C:\src\MyProject\docs"
setlocal
if "%~1"=="" (
  echo Usage: reindex.cmd ^<path-to-project-docs^>
  exit /b 1
)
"%~dp0local-tools\bin\Release\net8.0\local-tools.exe" --reindex "%~1"
endlocal
