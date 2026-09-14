@echo off
setlocal
cd /d "%~dp0mobile"
set "FLUTTER_PREBUILT_ENGINE_VERSION=a804b261645ef8c13eb3d5c44a5c2fb0340c5539"
set "PUB_CACHE=%~dp0..\..\work\pub-cache"
set "ELMA_FLUTTER=%~dp0..\..\work\flutter\bin\flutter.bat"
if not exist "%ELMA_FLUTTER%" set "ELMA_FLUTTER=flutter"
call "%ELMA_FLUTTER%" run --dart-define=API_BASE_URL=https://elmaclinic-api.vercel.app/api/v1/
pause
