@echo off
setlocal enabledelayedexpansion

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

set "SCENE=%~1"
if "%SCENE%"=="" set "SCENE=res://source/Main.tscn"

set "GODOT_BIN="
set "GODOT_CONSOLE="

for %%P in (
    "%PROJECT_DIR%\tmp\tooling\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
    "%LOCALAPPDATA%\Temp\OpenRTSPolish-20261024\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
    "%LOCALAPPDATA%\Godot\Godot_v4.7.2-stable_win64.exe"
) do (
    if not defined GODOT_BIN if exist "%%~fP" (
        set "GODOT_BIN=%%~fP"
        set "GODOT_DIR=%%~dpP"
        if exist "!GODOT_DIR!Godot_v4.7.2-stable_win64_console.exe" (
            set "GODOT_CONSOLE=!GODOT_DIR!Godot_v4.7.2-stable_win64_console.exe"
        )
    )
)

if not defined GODOT_BIN (
    for %%C in (godot4.exe godot.exe Godot_v4.7.2-stable_win64.exe) do (
        if not defined GODOT_BIN (
            for /f "delims=" %%W in ('where %%C 2^>nul') do (
                if not defined GODOT_BIN (
                    for /f "delims=" %%V in ('"%%W" --version 2^>nul') do (
                        echo %%V | findstr /b "4.7.2.stable." >nul && set "GODOT_BIN=%%W"
                    )
                )
            )
        )
    )
)

if not defined GODOT_BIN (
    echo Godot 4.7.2 is required. Place Godot_v4.7.2-stable_win64.exe in tmp\tooling\godot-4.7.2\ or add godot to PATH.
    exit /b 1
)

if not defined GODOT_CONSOLE set "GODOT_CONSOLE=%GODOT_BIN%"

if not exist "%PROJECT_DIR%\.godot\imported" (
    echo Importing project assets for Windows ^(first run^)...
    "%GODOT_CONSOLE%" --headless --editor --path "%PROJECT_DIR%" --import
    if errorlevel 1 exit /b !errorlevel!
)

set "NATIVE_FLAGS="
if exist "%PROJECT_DIR%\native\bin\copperfin.gdextension" (
    set "NATIVE_FLAGS=-- --native-unit-state --native-crowd-runtime --native-nearest-surface --native-visibility-runtime --native-exploration --native-combat-queries --native-battlefield-index --native-infantry-poses --native-presentation --indexed-player-rosters"
)

start "" "%GODOT_BIN%" --path "%PROJECT_DIR%" "%SCENE%" %NATIVE_FLAGS%
exit /b 0
