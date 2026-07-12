@echo off
chcp 65001 >nul
title AI会社チーム
setlocal

REM ── 設定 ─────────────────────────────────────────────
set "APPDIR=%USERPROFILE%\AITeamWeb"
set "APPFILE=%APPDIR%\app.py"
set "RAWURL=https://raw.githubusercontent.com/masaya031417-coder/samuraidamashii/claude/multi-ai-team-cli-CUSOI/team-cli/python-app/app.py"

echo ============================================
echo    AI会社チーム を起動します
echo ============================================
echo.

if not exist "%APPDIR%" mkdir "%APPDIR%"

REM ── 最新版を自動ダウンロード ──────────────────────────
echo [1/3] 最新版をダウンロード中...
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%RAWURL%' -OutFile '%APPFILE%' -UseBasicParsing } catch { exit 1 }"
if errorlevel 1 (
  echo     [警告] ダウンロード失敗。既存ファイルで起動を試みます。
) else (
  echo     完了。
)

if not exist "%APPFILE%" (
  echo.
  echo [エラー] app.py が見つかりません。ネット接続を確認してください。
  echo.
  pause
  exit /b 1
)

REM ── Pythonを探す ─────────────────────────────────────
echo [2/3] Python を確認中...
set "PYEXE="
if exist "%LOCALAPPDATA%\Programs\Python\Python310\python.exe" set "PYEXE=%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
if not defined PYEXE (
  where py >nul 2>&1 && set "PYEXE=py"
)
if not defined PYEXE (
  where python >nul 2>&1 && set "PYEXE=python"
)

if not defined PYEXE (
  echo.
  echo [エラー] Python が見つかりません。
  echo         https://www.python.org からインストールしてください。
  echo.
  pause
  exit /b 1
)
echo     Python: %PYEXE%

REM ── ブラウザを3秒後に開く ────────────────────────────
echo [3/3] サーバーを起動します...
start "" cmd /c "timeout /t 3 >nul & start "" http://localhost:5000"

echo.
echo ============================================
echo    起動中！ブラウザが自動で開きます。
echo    停止するには このウィンドウを閉じてください。
echo ============================================
echo.

"%PYEXE%" "%APPFILE%"

echo.
echo サーバーが停止しました。
pause
