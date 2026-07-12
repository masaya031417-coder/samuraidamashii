@echo off
chcp 65001 >nul
title AI会社チーム
setlocal enabledelayedexpansion

echo ==================================================
echo    AI会社チーム  セットアップ ＆ 起動
echo ==================================================
echo.

set "APPDIR=%USERPROFILE%\AITeamWeb"
set "APPFILE=%APPDIR%\app.py"
set "RAWURL=https://raw.githubusercontent.com/masaya031417-coder/samuraidamashii/claude/multi-ai-team-cli-CUSOI/team-cli/python-app/app.py"

if not exist "%APPDIR%" mkdir "%APPDIR%"

REM ========== [1/4] Python を確認 ==========
echo [1/4] Python を確認しています...
set "PYEXE="
if exist "%LOCALAPPDATA%\Programs\Python\Python310\python.exe" set "PYEXE=%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
if not defined PYEXE ( where py >nul 2>&1 && set "PYEXE=py" )
if not defined PYEXE ( where python >nul 2>&1 && set "PYEXE=python" )

if not defined PYEXE (
  echo.
  echo    [X] Python が見つかりませんでした。
  echo.
  echo    → https://www.python.org/downloads/ から Python をインストールし、
  echo       インストール時に「Add Python to PATH」に必ずチェックを入れてください。
  echo.
  echo    インストール後、もう一度この AIチーム.bat をダブルクリックしてください。
  echo.
  pause
  exit /b 1
)
echo    OK : %PYEXE%
echo.

REM ========== [2/4] Claude Code を確認 ==========
echo [2/4] Claude Code (claude コマンド) を確認しています...
where claude >nul 2>&1
if errorlevel 1 (
  echo.
  echo    [X] claude コマンドが見つかりませんでした。
  echo.
  echo    Claude Code が入っていないか、PATH が通っていません。
  echo    コマンドプロンプトで次を実行してインストールできます:
  echo.
  echo        npm install -g @anthropic-ai/claude-code
  echo.
  echo    ※ Node.js が必要です ( https://nodejs.org )。
  echo    インストール後、もう一度この AIチーム.bat をダブルクリックしてください。
  echo.
  pause
  exit /b 1
)
echo    OK : claude 見つかりました
echo.

REM ========== [3/4] 最新のアプリ本体をダウンロード ==========
echo [3/4] アプリ本体 (app.py) を最新版に更新しています...
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%RAWURL%' -OutFile '%APPFILE%' -UseBasicParsing; exit 0 } catch { exit 1 }"
if errorlevel 1 (
  if exist "%APPFILE%" (
    echo    [!] ダウンロードに失敗。既存のファイルで続行します。
  ) else (
    echo.
    echo    [X] app.py のダウンロードに失敗し、手元にもファイルがありません。
    echo        インターネット接続を確認して、もう一度お試しください。
    echo.
    pause
    exit /b 1
  )
) else (
  echo    OK : 最新版に更新しました
)
echo.

REM ========== [4/4] サーバー起動 ==========
echo [4/4] サーバーを起動します...
echo.
echo    3秒後にブラウザが自動で開きます。
echo    ------------------------------------------------
echo    停止したいときは、この黒い画面を閉じてください。
echo    ------------------------------------------------
echo.

start "" cmd /c "timeout /t 3 >nul & start "" http://localhost:5000"

"%PYEXE%" "%APPFILE%"

echo.
echo サーバーが停止しました。何かキーを押すと閉じます。
pause >nul
