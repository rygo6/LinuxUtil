@echo off
rem ###########################################################################
rem setup-agent-skills.cmd
rem
rem Runs setup-agent-skills.sh from cmd or PowerShell. The script needs a
rem bash with git, cygpath, and ssh, so it uses Git Bash if installed and
rem falls back to MSYS2. `bash` on PATH is not used, since it may be WSL's,
rem which cannot see the Windows profile as %USERPROFILE%.
rem
rem Usage: setup-agent-skills.cmd [skill...]     (default: all of them)
rem ###########################################################################
setlocal

set "SCRIPT=%~dp0setup-agent-skills.sh"
set "SCRIPT=%SCRIPT:\=/%"

set "BASH="
set "BASH_ARGS="
for %%B in (
    "%ProgramFiles%\Git\bin\bash.exe"
    "%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
) do if not defined BASH if exist %%B set "BASH=%%~B"

rem MSYS2's bash only sets up PATH as a login shell; CHERE_INVOKING keeps
rem the login profile from changing to $HOME.
if not defined BASH if exist "C:\msys64\usr\bin\bash.exe" (
    set "BASH=C:\msys64\usr\bin\bash.exe"
    set "BASH_ARGS=-l"
    set "MSYSTEM=MSYS"
    set "CHERE_INVOKING=1"
)

if not defined BASH (
    echo ERROR: Neither Git Bash nor MSYS2 was found. Install Git for Windows: 1>&2
    echo        winget install --id Git.Git -e 1>&2
    exit /b 1
)

rem Run outside any ( ) block so %ERRORLEVEL% is read after bash exits.
"%BASH%" %BASH_ARGS% "%SCRIPT%" %*
exit /b %ERRORLEVEL%
