@echo off
REM Carnama gate runner. Thin wrapper: all logic lives in tool\gate.mjs so the
REM same gates run identically from cmd.exe, PowerShell and Git Bash.
REM
REM   gate.cmd                 -> same as "gate.cmd check"
REM   gate.cmd check           -> run every gate
REM   gate.cmd check --only=a,e -> run selected gates
REM   gate.cmd list            -> show the gate table
REM
REM Exit codes: 0 = no gate FAILED, 1 = at least one gate FAILED, 2 = usage error.
setlocal
node "%~dp0tool\gate.mjs" %*
exit /b %ERRORLEVEL%
