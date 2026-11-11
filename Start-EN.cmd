@echo off
setlocal
echo WinFix - System Health Report
echo Read-only. Reports stay on your computer.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0script\WinFix-SystemHealthReport.ps1" -Language en -OutputDirectory "%~dp0WinFix-Reports" -OpenReport
set "result=%errorlevel%"
if "%result%"=="1" echo Failed. See the message above.
if "%result%"=="2" echo Partial report: some sources are unavailable.
pause
exit /b %result%
