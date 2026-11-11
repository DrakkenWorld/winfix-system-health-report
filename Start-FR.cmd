@echo off
setlocal
echo WinFix - Rapport de sante du systeme
echo Lecture seule. Les rapports restent sur votre ordinateur.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0script\WinFix-SystemHealthReport.ps1" -Language fr -OutputDirectory "%~dp0WinFix-Reports" -OpenReport
set "result=%errorlevel%"
if "%result%"=="1" echo Echec. Consultez le message ci-dessus.
if "%result%"=="2" echo Rapport partiel : certaines sources sont inaccessibles.
pause
exit /b %result%
