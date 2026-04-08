@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%digest-intent.cmd" AI???? %*
exit /b %ERRORLEVEL%
