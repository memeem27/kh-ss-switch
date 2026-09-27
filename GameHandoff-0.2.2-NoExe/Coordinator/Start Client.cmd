@echo off
cd /d "%~dp0"
where dotnet >nul 2>nul
if errorlevel 1 (
  echo Microsoft .NET 8 Runtime is required. Run the preflight checker for details.
  pause
  exit /b 1
)
dotnet "%~dp0GameHandoff.Coordinator.dll" "%~dp0client.ini"
pause
