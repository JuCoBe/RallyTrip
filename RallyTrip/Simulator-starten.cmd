@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-simulator.ps1" %*
set "rallyExitCode=%errorlevel%"
if not "%rallyExitCode%"=="0" pause
exit /b %rallyExitCode%
