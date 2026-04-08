@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%digest-intent.cmd" ??????? %*
exit /b %ERRORLEVEL%
