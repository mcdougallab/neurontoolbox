@echo off
setlocal EnableDelayedExpansion

set "TOOLBOX_DIR=%~dp0"
if "!TOOLBOX_DIR:~-1!"=="\" set "TOOLBOX_DIR=!TOOLBOX_DIR:~0,-1!"
set "INSTALL_STATE_FILE=!TOOLBOX_DIR!\.nrnml_install_state.cmd"

echo.
echo === Step 1: Locating Python ^& NEURON ===

:: Prefer 'python' (picks up active conda env) over 'python3'
set "_PYTHON="
for %%P in (python python3) do (
    if not defined _PYTHON (
        where %%P >nul 2>&1 && set "_PYTHON=%%P"
    )
)
if not defined _PYTHON (
    echo   ERROR: Python not found. Activate your conda environment first.
    exit /b 1
)
echo   Python: !_PYTHON!

:: Try pip-installed NEURON first
set "NRN_DATA_DIR="
"%_PYTHON%" -c "import neuron, os; p=os.path.join(os.path.dirname(neuron.__file__),'.data'); print(p if os.path.isfile(os.path.join(p,'lib','libnrniv.dll')) else '', end='')" > "%TEMP%\nrnml_nrndir.txt" 2>nul
set /p _NRN_CANDIDATE=<"%TEMP%\nrnml_nrndir.txt"
del "%TEMP%\nrnml_nrndir.txt" >nul 2>&1
if defined _NRN_CANDIDATE (
    if exist "!_NRN_CANDIDATE!\lib\libnrniv.dll" (
        set "NRN_DATA_DIR=!_NRN_CANDIDATE!"
        echo   Found NEURON ^(pip^) at: !NRN_DATA_DIR!
    )
)

:: Fall back to standard installer location
if not defined NRN_DATA_DIR (
    if exist "C:\nrn\bin\libnrniv.dll" (
        set "NRN_DATA_DIR=C:\nrn"
        echo   Found NEURON at: !NRN_DATA_DIR!
    )
)

if not defined NRN_DATA_DIR (
    echo.
    echo   NEURON not found automatically.
    echo   Install NEURON 9+ from https://www.neuronsimulator.org
    echo.
    set /p "NRN_DATA_DIR=  Enter NEURON root (parent of bin\ and include\): "
)

:: pip installs put the DLL under lib\, standard installers put it under bin\
set "LIBNRNIV="
set "NRN_RUNTIME_DIR="
if exist "!NRN_DATA_DIR!\lib\libnrniv.dll" set "LIBNRNIV=!NRN_DATA_DIR!\lib\libnrniv.dll"
if exist "!NRN_DATA_DIR!\lib\libnrniv.dll" set "NRN_RUNTIME_DIR=!NRN_DATA_DIR!\lib"
if exist "!NRN_DATA_DIR!\bin\libnrniv.dll" set "LIBNRNIV=!NRN_DATA_DIR!\bin\libnrniv.dll"
if exist "!NRN_DATA_DIR!\bin\libnrniv.dll" set "NRN_RUNTIME_DIR=!NRN_DATA_DIR!\bin"
if not defined LIBNRNIV (
    echo   ERROR: libnrniv.dll not found under !NRN_DATA_DIR!
    exit /b 1
)

set "NEURONAPI_H=!NRN_DATA_DIR!\include\neuronapi.h"
set "HOC_DIR=!NRN_DATA_DIR!\share\nrn\lib\hoc"
if not exist "!NEURONAPI_H!" (
    echo   ERROR: neuronapi.h not found at !NEURONAPI_H!
    exit /b 1
)

echo   libnrniv:    !LIBNRNIV!
echo   neuronapi.h: !NEURONAPI_H!
echo   HOC dir:     !HOC_DIR!
echo   runtime dir: !NRN_RUNTIME_DIR!

:: ── Step 2: Find MATLAB ──────────────────────────────────────────────────────
echo.
echo === Step 2: Locating MATLAB ===

set "MATLAB_BIN="
where matlab >nul 2>&1 && (
    for /f "delims=" %%i in ('where matlab 2^>nul') do if not defined MATLAB_BIN set "MATLAB_BIN=%%i"
)

if not defined MATLAB_BIN (
    for /d %%i in ("C:\Program Files\MATLAB\R*") do (
        if exist "%%i\bin\matlab.exe" set "MATLAB_BIN=%%i\bin\matlab.exe"
    )
)

if not defined MATLAB_BIN (
    echo   MATLAB not found automatically.
    set /p "MATLAB_BIN=  Enter full path to matlab.exe: "
)
if not exist "!MATLAB_BIN!" (
    echo   ERROR: Not found: !MATLAB_BIN!
    exit /b 1
)
echo   MATLAB: !MATLAB_BIN!

echo   Querying matlabroot (this may take a moment) ...
"!MATLAB_BIN!" -batch "disp(matlabroot)" > "%TEMP%\nrnml_mlroot.txt" 2>nul
set "MATLAB_ROOT="
set /p MATLAB_ROOT=<"%TEMP%\nrnml_mlroot.txt"
del "%TEMP%\nrnml_mlroot.txt" >nul 2>&1

if not defined MATLAB_ROOT (
    :: Fallback: go up two directories from bin\matlab.exe
    for %%i in ("!MATLAB_BIN!") do set "_BINDIR=%%~dpi"
    for %%i in ("!_BINDIR:~0,-1!") do set "MATLAB_ROOT=%%~dpi"
    if "!MATLAB_ROOT:~-1!"=="\" set "MATLAB_ROOT=!MATLAB_ROOT:~0,-1!"
)
echo   matlabroot: !MATLAB_ROOT!
set "MATLAB_LIB_DIR=!MATLAB_ROOT!\bin\win64"

:: ── Step 3: Patch source\neuron_api.cpp ──────────────────────────────────────
echo.
echo === Step 3: Patching source\neuron_api.cpp ===

set "CPP_FILE=!TOOLBOX_DIR!\source\neuron_api.cpp"
if not exist "!CPP_FILE!" (
    echo   ERROR: Not found: !CPP_FILE!
    exit /b 1
)

:: Patch to a temp file — the original source is never modified
set "PATCHED_CPP=%TEMP%\neuron_api_patched.cpp"

:: Use the checked-in patch helper to avoid brittle batch escaping.
set "PATCHER=!TOOLBOX_DIR!\tools\nrnml_patch.py"
if not exist "!PATCHER!" (
    echo   ERROR: Not found: !PATCHER!
    exit /b 1
)

"%_PYTHON%" "!PATCHER!" "!CPP_FILE!" "!PATCHED_CPP!" "!NEURONAPI_H!" "!LIBNRNIV!"
if errorlevel 1 (
    echo   ERROR: Failed to patch neuron_api.cpp
    exit /b 1
)
echo   neuronapi.h ^-^> !NEURONAPI_H!
echo   libnrniv    ^-^> !LIBNRNIV!

:: ── Step 4: libmodlreg — not needed on Windows ───────────────────────────────
echo.
echo === Step 4: libmodlreg ===
echo   Skipped (guarded by #ifndef _WIN32 in neuron_api.cpp)

:: ── Step 5: Compile neuron_api MEX ───────────────────────────────────────────
echo.
echo === Step 5: Compiling neuron_api MEX ===

:: Forward-slash path required by MATLAB's cd() and fullfile()
set "TOOLBOX_FWD=!TOOLBOX_DIR:\=/!"
set "PATCHED_FWD=!PATCHED_CPP:\=/!"
set "MEX_CMDS=mex('CXXFLAGS=$CXXFLAGS -std=c++17', '-output', fullfile('!TOOLBOX_FWD!','neuron_api'), '!PATCHED_FWD!')"

echo   Trying mex ...
"!MATLAB_BIN!" -batch "!MEX_CMDS!" >nul 2>&1
if not errorlevel 1 (
    echo   MEX compilation succeeded ^(via mex^)
    del "!PATCHED_CPP!" >nul 2>&1
    goto :mex_done
)

:: Fallback: compile with MinGW g++ directly
echo   mex compilation failed; trying MinGW g++ fallback ...
where g++ >nul 2>&1
if errorlevel 1 (
    echo   ERROR: g++ not found.
    echo   Install MinGW-w64, add its bin\ to PATH, then re-run this installer.
    exit /b 1
)

set "MEX_OUT=!TOOLBOX_DIR!\neuron_api.mexw64"
set "MATLAB_INCLUDE=!MATLAB_ROOT!\extern\include"

g++ -std=c++17 -DMATLAB_MEX_FILE -shared ^
    -I"!MATLAB_INCLUDE!" -I"!NRN_DATA_DIR!\include" ^
    "!PATCHED_CPP!" ^
    -L"!MATLAB_LIB_DIR!" -lmex -lmx ^
    -o "!MEX_OUT!"
if errorlevel 1 (
    del "!PATCHED_CPP!" >nul 2>&1
    echo   ERROR: MEX compilation failed.
    exit /b 1
)
del "!PATCHED_CPP!" >nul 2>&1
echo   Built: !MEX_OUT!

:mex_done

:: ── Step 6: Update user environment variables ────────────────────────────────
echo.
echo === Step 6: Configuring user environment ===

:: Use the checked-in helper for reliable append-without-duplicate and broadcast.
set "ENV_UPDATER=!TOOLBOX_DIR!\tools\nrnml_setenv.py"
set "ENV_CONTAINS=!TOOLBOX_DIR!\tools\nrnml_env_contains.py"
if not exist "!ENV_UPDATER!" (
    echo   ERROR: Not found: !ENV_UPDATER!
    exit /b 1
)
if not exist "!ENV_CONTAINS!" (
    echo   ERROR: Not found: !ENV_CONTAINS!
    exit /b 1
)

set "NRNML_ADDED_MATLABPATH=1"
"%_PYTHON%" "!ENV_CONTAINS!" MATLABPATH "!TOOLBOX_DIR!" >nul 2>&1
if not errorlevel 1 set "NRNML_ADDED_MATLABPATH=0"

set "NRNML_ADDED_HOC_DIR=1"
"%_PYTHON%" "!ENV_CONTAINS!" HOC_LIBRARY_PATH "!HOC_DIR!" >nul 2>&1
if not errorlevel 1 set "NRNML_ADDED_HOC_DIR=0"

set "NRNML_ADDED_RUNTIME_DIR=1"
"%_PYTHON%" "!ENV_CONTAINS!" PATH "!NRN_RUNTIME_DIR!" >nul 2>&1
if not errorlevel 1 set "NRNML_ADDED_RUNTIME_DIR=0"

"%_PYTHON%" "!ENV_UPDATER!" ^
    MATLABPATH      "!TOOLBOX_DIR!" ^
    HOC_LIBRARY_PATH "!HOC_DIR!" ^
    PATH            "!NRN_RUNTIME_DIR!"

:: startup.m runs on every MATLAB launch regardless of how MATLAB was started
echo   Updating MATLAB startup.m ...
"!MATLAB_BIN!" -batch "disp(userpath)" > "%TEMP%\nrnml_upath.txt" 2>nul
set "MATLAB_USERPATH="
set /p MATLAB_USERPATH=<"%TEMP%\nrnml_upath.txt"
del "%TEMP%\nrnml_upath.txt" >nul 2>&1
for /f "tokens=1 delims=;" %%i in ("!MATLAB_USERPATH!") do set "MATLAB_USERPATH=%%~i"
if not defined MATLAB_USERPATH set "MATLAB_USERPATH=%USERPROFILE%\Documents\MATLAB"
if not exist "!MATLAB_USERPATH!" mkdir "!MATLAB_USERPATH!"
set "STARTUP_M=!MATLAB_USERPATH!\startup.m"
set "ADDPATH_LINE=addpath('!TOOLBOX_DIR!');" 
set "NRNML_ADDED_STARTUP_LINE=1"
findstr /c:"!TOOLBOX_DIR!" "!STARTUP_M!" >nul 2>&1
if errorlevel 1 (
    echo !ADDPATH_LINE! >> "!STARTUP_M!"
    echo   Updated !STARTUP_M!
) else (
    set "NRNML_ADDED_STARTUP_LINE=0"
    echo   Already in startup.m, skipping
)

:: ── Done ─────────────────────────────────────────────────────────────────────
echo.
echo   Writing uninstall state ...
> "!INSTALL_STATE_FILE!" (
    echo @echo off
    echo set "NRNML_STATE_VERSION=1"
    echo set "NRNML_TOOLBOX_DIR=!TOOLBOX_DIR!"
    echo set "NRNML_HOC_DIR=!HOC_DIR!"
    echo set "NRNML_RUNTIME_DIR=!NRN_RUNTIME_DIR!"
    echo set "NRNML_STARTUP_M=!STARTUP_M!"
    echo set "NRNML_STARTUP_LINE=!ADDPATH_LINE!"
    echo set "NRNML_ADDED_MATLABPATH=!NRNML_ADDED_MATLABPATH!"
    echo set "NRNML_ADDED_HOC_DIR=!NRNML_ADDED_HOC_DIR!"
    echo set "NRNML_ADDED_RUNTIME_DIR=!NRNML_ADDED_RUNTIME_DIR!"
    echo set "NRNML_ADDED_STARTUP_LINE=!NRNML_ADDED_STARTUP_LINE!"
)
echo   State file: !INSTALL_STATE_FILE!
echo === Installation complete ===
echo.
echo Open a new Command Prompt so the updated environment takes effect,
echo then start MATLAB and verify with:
echo   run('!TOOLBOX_DIR!\examples\basic_functionality\example_run.m')
echo   run('!TOOLBOX_DIR!\examples\simulation\example_acpot.m')
echo.
