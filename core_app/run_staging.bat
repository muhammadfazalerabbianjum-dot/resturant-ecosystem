@echo off
setlocal
for /f "tokens=1,* delims==" %%A in (.env.staging) do (
    if not "%%A"=="" if not "%%A"==" " set %%A=%%B
)
call flutter clean
call flutter pub get
call flutter run --flavor staging --dart-define=FIREBASE_OPTIONS_PATH=%FIREBASE_OPTIONS_PATH% --profile
endlocal
