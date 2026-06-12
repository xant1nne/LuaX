@echo off
REM LuaX v0.2 — Windows launcher
setlocal
set SCRIPT_DIR=%~dp0
where luajit >nul 2>&1
if %ERRORLEVEL%==0 (
  luajit "%SCRIPT_DIR%luax.lua" %*
) else (
  lua "%SCRIPT_DIR%luax.lua" %*
)
