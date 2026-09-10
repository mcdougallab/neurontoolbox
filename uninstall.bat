@echo off
setlocal EnableDelayedExpansion

set "TOOLBOX_DIR=%~dp0"
if "!TOOLBOX_DIR:~-1!"=="\" set "TOOLBOX_DIR=!TOOLBOX_DIR:~0,-1!"
set "INSTALL_STATE_FILE=!TOOLBOX_DIR!\.nrnml_install_state.cmd"
set "UNINSTALL_HELPER=!TOOLBOX_DIR!\tools\nrnml_uninstall.ps1"

echo.
echo === Uninstalling MATLAB NEURON integration ===

if not exist "!INSTALL_STATE_FILE!" (
    echo   ERROR: Install state not found: !INSTALL_STATE_FILE!
    echo   Re-run install.bat first, or remove the persistent settings manually.
    exit /b 1
)

if not exist "!UNINSTALL_HELPER!" (
    echo   ERROR: Helper script not found: !UNINSTALL_HELPER!
    exit /b 1
)

call "!INSTALL_STATE_FILE!"

if not defined NRNML_TOOLBOX_DIR (
    echo   ERROR: Install state is missing NRNML_TOOLBOX_DIR
    exit /b 1
)

if "!NRNML_ADDED_MATLABPATH!"=="1" (
    echo   Removing MATLABPATH entry: !NRNML_TOOLBOX_DIR!
) else (
    echo   MATLABPATH entry was pre-existing, leaving it unchanged
)
if "!NRNML_ADDED_HOC_DIR!"=="1" (
    if defined NRNML_HOC_DIR echo   Removing HOC_LIBRARY_PATH entry: !NRNML_HOC_DIR!
) else (
    echo   HOC_LIBRARY_PATH entry was pre-existing, leaving it unchanged
)
if "!NRNML_ADDED_RUNTIME_DIR!"=="1" (
    if defined NRNML_RUNTIME_DIR echo   Removing PATH entry: !NRNML_RUNTIME_DIR!
) else (
    echo   PATH entry was pre-existing, leaving it unchanged
)
if "!NRNML_ADDED_STARTUP_LINE!"=="1" (
    if defined NRNML_STARTUP_M echo   Updating startup file: !NRNML_STARTUP_M!
) else (
    echo   startup.m entry was pre-existing, leaving it unchanged
)

powershell -NoProfile -ExecutionPolicy Bypass -File "!UNINSTALL_HELPER!" ^
    -ToolboxDir "!NRNML_TOOLBOX_DIR!" ^
    -HocDir "!NRNML_HOC_DIR!" ^
    -RuntimeDir "!NRNML_RUNTIME_DIR!" ^
    -StartupFile "!NRNML_STARTUP_M!" ^
    -StartupLine "!NRNML_STARTUP_LINE!" ^
    -StateFile "!INSTALL_STATE_FILE!" ^
    -AddedMatlabPath "!NRNML_ADDED_MATLABPATH!" ^
    -AddedHocDir "!NRNML_ADDED_HOC_DIR!" ^
    -AddedRuntimeDir "!NRNML_ADDED_RUNTIME_DIR!" ^
    -AddedStartupLine "!NRNML_ADDED_STARTUP_LINE!"
if errorlevel 1 (
    echo   ERROR: Uninstall failed.
    exit /b 1
)

echo.
echo === Uninstall complete ===
echo.
echo Open a new Command Prompt and restart MATLAB so the updated environment takes effect.
echo.
