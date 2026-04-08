@echo off
setlocal EnableExtensions
title Analyze AI Digest Health

set "PY=python"
set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..") do set "PROJECT_DIR=%%~fi"
set "SCRIPT=%SCRIPT_DIR%analyze-ai-digest-health.py"
set "LOGS_DIR=%PROJECT_DIR%\reports\health"
set "OUTPUT_PREFIX=%PROJECT_DIR%\reports\health\health-report"

if not exist "%SCRIPT%" (
  echo [ERROR] Script not found: %SCRIPT%
  pause
  exit /b 1
)

echo.
echo ==========================================
echo   Analyze AI Digest Health
echo ==========================================
echo.
echo Analyze window:
echo   1^) Last 2 days
echo   2^) Last 3 days (recommended)
echo   3^) Last 7 days
choice /C 123 /N /M "Choose 1-3: "
set "DAYS=3"
if errorlevel 3 set "DAYS=7"
if errorlevel 2 set "DAYS=3"
if errorlevel 1 set "DAYS=2"

echo.
echo Disable threshold (consecutive timeout/403 failures):
echo   1^) 2 (recommended)
echo   2^) 3
choice /C 12 /N /M "Choose 1-2: "
set "TH=2"
if errorlevel 2 set "TH=3"
if errorlevel 1 set "TH=2"

echo.
echo Running analysis...
%PY% "%SCRIPT%" --logs-dir "%LOGS_DIR%" --days %DAYS% --min-consecutive %TH% --output-prefix "%OUTPUT_PREFIX%"
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
  echo.
  echo [ERROR] Analysis failed.
  pause
  exit /b %RC%
)

echo.
echo [OK] Analysis completed.
echo JSON report: %OUTPUT_PREFIX%.json
echo MD report  : %OUTPUT_PREFIX%.md
pause
exit /b 0
