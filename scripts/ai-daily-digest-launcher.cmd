@echo off
setlocal EnableExtensions
title AI Daily Digest Launcher

set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..") do set "PROJECT_DIR=%%~fi"
set "OUTPUT_DIR=%PROJECT_DIR%\reports\output"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%PROJECT_DIR%\scripts\digest.ts" (
  echo [ERROR] Project script not found: %PROJECT_DIR%\scripts\digest.ts
  pause
  exit /b 1
)

if not exist "%PS_EXE%" (
  echo [ERROR] PowerShell not found: %PS_EXE%
  pause
  exit /b 1
)

echo.
echo ==========================================
echo   AI Daily Digest Launcher
echo ==========================================
echo.

echo [1/7] Select time range:
echo   1^) 24 hours
echo   2^) 48 hours (recommended)
echo   3^) 72 hours
echo   4^) 7 days (168 hours)
choice /C 1234 /N /M "Choose 1-4: "
set "HOURS=48"
if errorlevel 4 set "HOURS=168"
if errorlevel 3 set "HOURS=72"
if errorlevel 2 set "HOURS=48"
if errorlevel 1 set "HOURS=24"
echo Selected: %HOURS% hours
echo.

echo [2/7] Select article count:
echo   1^) 10
echo   2^) 15 (recommended)
echo   3^) 20
choice /C 123 /N /M "Choose 1-3: "
set "TOPN=15"
if errorlevel 3 set "TOPN=20"
if errorlevel 2 set "TOPN=15"
if errorlevel 1 set "TOPN=10"
echo Selected: %TOPN%
echo.

echo [3/7] Select language:
echo   1^) Chinese (zh)
echo   2^) English (en)
choice /C 12 /N /M "Choose 1-2: "
set "LANG=zh"
if errorlevel 2 set "LANG=en"
if errorlevel 1 set "LANG=zh"
echo Selected: %LANG%
echo.

echo [4/7] Include WaytoAGI latest posts:
echo   1^) Disable (0, default)
echo   2^) 5 posts
echo   3^) 10 posts
choice /C 123 /N /M "Choose 1-3: "
set "WAYTOAGI_LIMIT=0"
if errorlevel 3 set "WAYTOAGI_LIMIT=10"
if errorlevel 2 set "WAYTOAGI_LIMIT=5"
if errorlevel 1 set "WAYTOAGI_LIMIT=0"
echo Selected WaytoAGI limit: %WAYTOAGI_LIMIT%
echo.

echo [5/7] Select Gemini model:
echo   1^) gemini-flash-latest        ^(default / recommended^)
echo   2^) gemini-3-flash-preview
echo   3^) gemini-3-pro-preview
echo   4^) gemini-3.1-pro-preview
echo   5^) Custom model name
set /p MODEL_CHOICE=Choose 1-5: 
set "GEMINI_MODEL=gemini-flash-latest"
if "%MODEL_CHOICE%"=="5" goto model_custom
if "%MODEL_CHOICE%"=="4" set "GEMINI_MODEL=gemini-3.1-pro-preview"
if "%MODEL_CHOICE%"=="3" set "GEMINI_MODEL=gemini-3-pro-preview"
if "%MODEL_CHOICE%"=="2" set "GEMINI_MODEL=gemini-3-flash-preview"
if "%MODEL_CHOICE%"=="1" set "GEMINI_MODEL=gemini-flash-latest"
goto model_done

:model_custom
set /p GEMINI_MODEL=Enter custom Gemini model name: 

:model_done
if "%GEMINI_MODEL%"=="" (
  set "GEMINI_MODEL=gemini-flash-latest"
)
echo Selected Gemini model: %GEMINI_MODEL%
echo.

echo [6/7] Select OpenAI fallback model:
echo   1^) gpt-5.4 (default)
echo   2^) Use current OPENAI_MODEL from environment
echo   3^) gpt-5.3-codex
echo   4^) Custom model name
set /p OPENAI_MODEL_CHOICE=Choose 1-4: 
set "OPENAI_MODEL_OVERRIDE=gpt-5.4"
set "OPENAI_MODEL_LABEL=gpt-5.4"
if "%OPENAI_MODEL_CHOICE%"=="4" goto openai_model_custom
if "%OPENAI_MODEL_CHOICE%"=="3" (
  set "OPENAI_MODEL_OVERRIDE=gpt-5.3-codex"
  set "OPENAI_MODEL_LABEL=gpt-5.3-codex"
)
if "%OPENAI_MODEL_CHOICE%"=="2" (
  set "OPENAI_MODEL_OVERRIDE="
  set "OPENAI_MODEL_LABEL=(env OPENAI_MODEL)"
)
if "%OPENAI_MODEL_CHOICE%"=="1" (
  set "OPENAI_MODEL_OVERRIDE=gpt-5.4"
  set "OPENAI_MODEL_LABEL=gpt-5.4"
)
goto openai_model_done

:openai_model_custom
set /p OPENAI_MODEL_OVERRIDE=Enter custom OpenAI model name: 
if "%OPENAI_MODEL_OVERRIDE%"=="" (
  set "OPENAI_MODEL_LABEL=(env OPENAI_MODEL)"
) else (
  set "OPENAI_MODEL_LABEL=%OPENAI_MODEL_OVERRIDE%"
)

:openai_model_done
echo Selected OpenAI fallback model: %OPENAI_MODEL_LABEL%
echo.

echo [7/7] Confirm:
echo   Hours  : %HOURS%
echo   Top N  : %TOPN%
echo   Lang   : %LANG%
echo   WaytoAGI latest: %WAYTOAGI_LIMIT%
echo   Gemini : %GEMINI_MODEL%
echo   OpenAI fallback: %OPENAI_MODEL_LABEL%
echo   Project: %PROJECT_DIR%
echo   Output : %OUTPUT_DIR%
echo.
choice /C YN /N /M "Start now? (Y/N): "
if errorlevel 2 (
  echo Cancelled.
  pause
  exit /b 0
)

echo.
echo Generating digest, please wait...

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if not exist "%PROJECT_DIR%\\reports\\health" mkdir "%PROJECT_DIR%\\reports\\health"
for /f %%i in ('"%PS_EXE%" -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmm"') do set "TS=%%i"
set "OUTPUT_FILE=%OUTPUT_DIR%\ai-daily-digest-%TS%.md"
set "HEALTH_LOG_FILE=%PROJECT_DIR%\\reports\\health\\run-%TS%.json"

if "%OPENAI_MODEL_OVERRIDE%"=="" (
  set "OPENAI_MODEL_EFFECTIVE=%OPENAI_MODEL%"
) else (
  set "OPENAI_MODEL_EFFECTIVE=%OPENAI_MODEL_OVERRIDE%"
)

if "%GEMINI_API_KEY%"=="" if "%OPENAI_API_KEY%"=="" (
  echo [ERROR] Missing API key. Please set GEMINI_API_KEY and/or OPENAI_API_KEY in User environment variables.
  pause
  exit /b 1
)

pushd "%PROJECT_DIR%"
set "GEMINI_MODEL=%GEMINI_MODEL%"
if not "%OPENAI_MODEL_EFFECTIVE%"=="" set "OPENAI_MODEL=%OPENAI_MODEL_EFFECTIVE%"
npx -y bun scripts/digest.ts --hours %HOURS% --top-n %TOPN% --lang %LANG% --waytoagi-limit %WAYTOAGI_LIMIT% --output "%OUTPUT_FILE%" --health-log "%HEALTH_LOG_FILE%"
set "RUN_EXIT=%ERRORLEVEL%"
popd

if not "%RUN_EXIT%"=="0" (
  echo.
  echo [ERROR] Generation failed. Check network and API settings.
  pause
  exit /b 1
)

echo.
echo [OK] Done.
echo Output file: %OUTPUT_FILE%
echo Health log : %HEALTH_LOG_FILE%
echo Output folder: %OUTPUT_DIR%
pause
exit /b 0
