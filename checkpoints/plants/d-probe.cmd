@echo off
cd /d <repo>\core_app
firebase emulators:exec --only firestore --project demo-carnama-gate "node ../tool/emulator_boot_probe.mjs"
exit /b %ERRORLEVEL%
