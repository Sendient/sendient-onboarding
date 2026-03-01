@echo off
rem sendient-claude.cmd — Sendient wrapper for Claude Code (Windows)
rem Displays the SREE methodology banner, then launches the real claude.cmd.

setlocal EnableDelayedExpansion

rem --- Check for non-interactive flags (skip banner) ---
set "SHOW_BANNER=1"
for %%A in (%*) do (
    if /I "%%~A"=="-p"        set "SHOW_BANNER=0"
    if /I "%%~A"=="--print"   set "SHOW_BANNER=0"
    if /I "%%~A"=="--json"    set "SHOW_BANNER=0"
    if /I "%%~A"=="--version" set "SHOW_BANNER=0"
    if /I "%%~A"=="-v"        set "SHOW_BANNER=0"
)

rem --- Find the real claude binary ---
rem Prefer the native install location, then fall back to PATH search
set "SELF_DIR=%~dp0"
rem Remove trailing backslash for comparison
if "%SELF_DIR:~-1%"=="\" set "SELF_DIR=%SELF_DIR:~0,-1%"

set "REAL_CLAUDE="
set "NATIVE_CLAUDE=%USERPROFILE%\.local\bin\claude.exe"

rem 1. Native install (preferred)
if exist "!NATIVE_CLAUDE!" (
    set "REAL_CLAUDE=!NATIVE_CLAUDE!"
    goto :donefind
)

rem 2. Search PATH, skipping our own directory
set "SEARCH_PATH=%PATH%"

:findloop
if "%SEARCH_PATH%"=="" goto :donefind
for /f "tokens=1* delims=;" %%a in ("%SEARCH_PATH%") do (
    set "DIR=%%a"
    set "SEARCH_PATH=%%b"
)
rem Remove trailing backslash from DIR for comparison
if "!DIR:~-1!"=="\" set "DIR=!DIR:~0,-1!"
if /I "!DIR!"=="!SELF_DIR!" goto :findloop
if exist "!DIR!\claude.exe" (
    set "REAL_CLAUDE=!DIR!\claude.exe"
    goto :donefind
)
if exist "!DIR!\claude.cmd" (
    set "REAL_CLAUDE=!DIR!\claude.cmd"
    goto :donefind
)
goto :findloop

:donefind
if not defined REAL_CLAUDE (
    echo Error: Could not find the real Claude Code binary. >&2
    echo Install it first: https://code.claude.com/docs/setup >&2
    exit /b 1
)

rem --- Show banner for interactive sessions ---
if "%SHOW_BANNER%"=="0" goto :launch

rem ANSI escape character (0x1B)
for /f %%e in ('echo prompt $E ^| cmd') do set "ESC=%%e"

set "DIM=%ESC%[2m"
set "BOLD=%ESC%[1m"
set "CYAN=%ESC%[36m"
set "WHITE=%ESC%[37m"
set "YELLOW=%ESC%[33m"
set "RESET=%ESC%[0m"
set "BC=%BOLD%%CYAN%"
set "BY=%BOLD%%YELLOW%"

echo.
echo %DIM%+---------------------------------------------------+%RESET%
echo %DIM%^|%RESET%  %BC%Sendient AI - SREE Framework%RESET%                   %DIM%^|%RESET%
echo %DIM%^|%RESET%                                                 %DIM%^|%RESET%
echo %DIM%^|%RESET%  %BY%/scope%RESET%    - Define what you want to achieve    %DIM%^|%RESET%
echo %DIM%^|%RESET%  %BY%/refine%RESET%   - Clarify requirements ^& constraints %DIM%^|%RESET%
echo %DIM%^|%RESET%  %BY%/execute%RESET%  - Implement the solution             %DIM%^|%RESET%
echo %DIM%^|%RESET%  %BY%/evaluate%RESET% - Review, confirm, document, merge   %DIM%^|%RESET%
echo %DIM%^|%RESET%                                                 %DIM%^|%RESET%
echo %DIM%^|%RESET%  %DIM%Start any session with %WHITE%/scope%DIM%, or pick up%RESET%      %DIM%^|%RESET%
echo %DIM%^|%RESET%  %DIM%where you left off with %WHITE%/refine%DIM%, or %WHITE%/execute%DIM%.%RESET%  %DIM%^|%RESET%
echo %DIM%+---------------------------------------------------+%RESET%

:launch
rem Pass REAL_CLAUDE across the endlocal boundary
endlocal & set "REAL_CLAUDE=%REAL_CLAUDE%"
rem Pass all arguments through to the real claude
"%REAL_CLAUDE%" %*
