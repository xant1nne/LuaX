@echo off
REM LuaX v0.2 build helper
set LUA=lua
where luajit >nul 2>&1 && set LUA=luajit

if "%1"=="test" goto test
if "%1"=="example" goto example
if "%1"=="clean" goto clean
echo Usage: build.bat [test^|example^|clean]
exit /b 1

:test
%LUA% tests\test_all.lua || exit /b 1
%LUA% tests\test_errors.lua || exit /b 1
%LUA% tests\compat\lua_compat.lua || exit /b 1
exit /b 0

:example
%LUA% luax.lua build examples\example_complete.lx
exit /b 0

:clean
del /q examples\*.lua 2>nul
del /q *.luax.tmp.lua 2>nul
exit /b 0
