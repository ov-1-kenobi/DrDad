@echo off
REM grade-trends.cmd - the computed half of a retrospective: grade direction, units that needed rework,
REM stub cards, and recurring themes across every card in grades\. /retro turns these into proposals.
REM   grade-trends.cmd
REM   grade-trends.cmd -ProjectDir C:\src\App
REM   grade-trends.cmd -Json
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0grade-trends.ps1" %*
