# Claude Code × Codex 連結パイプライン（Windows PowerShell用）
#
# 使い方:
#   powershell -ExecutionPolicy Bypass -File .\scripts\connect-codex.ps1 -Topic "相談したい内容"
#
# 流れ:
#   1. Claude Code (claude -p) が初期案を作成 → ai-work\claude-draft.md
#   2. Codex (codex exec) が敵対的レビュー   → ai-work\codex-review.md
#   3. Claude Code が両者を統合した最終案     → ai-work\final-answer.md

param(
    [string]$Topic = "一人法人AIエージェント会社の最初のMVPに必要な機能を決めたい。"
)

$ErrorActionPreference = "Stop"

# --- 0. 事前確認 -----------------------------------------------------------
Write-Host "=== 事前確認 ===" -ForegroundColor Cyan

$claudeVersion = & claude --version 2>$null
if (-not $claudeVersion) {
    Write-Host "NG: claude コマンドが見つかりません。Claude Code をインストールしてください。" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Claude Code $claudeVersion"

$codexVersion = & codex --version 2>$null
if (-not $codexVersion) {
    Write-Host "NG: codex コマンドが見つかりません。npm install -g @openai/codex を実行してください。" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Codex $codexVersion"

New-Item -ItemType Directory -Force -Path ".\ai-work" | Out-Null

# --- 1. Claude が初期案を作成 ----------------------------------------------
Write-Host "`n=== ステップ1: Claude が初期案を作成 ===" -ForegroundColor Cyan

$draftPrompt = @"
次のテーマについて、あなた自身の独立した初期案を作成してください。
Markdown形式で、結論・理由・具体的な構成の順に書いてください。
テーマ: $Topic
"@

& claude -p $draftPrompt | Out-File -Encoding utf8 ".\ai-work\claude-draft.md"
if ($LASTEXITCODE -ne 0) { Write-Host "NG: Claude の実行に失敗しました。" -ForegroundColor Red; exit 1 }
Write-Host "保存しました: ai-work\claude-draft.md"

# --- 2. Codex が敵対的レビュー ---------------------------------------------
Write-Host "`n=== ステップ2: Codex がレビュー ===" -ForegroundColor Cyan

$draft = Get-Content -Raw ".\ai-work\claude-draft.md"
$reviewPrompt = @"
以下はClaudeが作成した初期案です。敵対的レビュアーとして、
論理矛盾・前提の不足・実現可能性・実装難易度・コスト・セキュリティ・
保守性・拡張性・事業価値・見落としている反対意見 の観点から指摘してください。

--- 初期案ここから ---
$draft
--- 初期案ここまで ---
"@

& codex exec $reviewPrompt | Out-File -Encoding utf8 ".\ai-work\codex-review.md"
if ($LASTEXITCODE -ne 0) {
    Write-Host "NG: Codex未実行（codex exec が失敗しました）。ログインや通信環境を確認してください。" -ForegroundColor Red
    exit 1
}
Write-Host "保存しました: ai-work\codex-review.md"

# --- 3. Claude が統合して最終案を作成 --------------------------------------
Write-Host "`n=== ステップ3: Claude が統合 ===" -ForegroundColor Cyan

$review = Get-Content -Raw ".\ai-work\codex-review.md"
$finalPrompt = @"
あなたの初期案と、Codexによるレビューを比較し、最終推奨案をまとめてください。
報告形式:
1. 両者の一致点
2. 両者の相違点
3. 採用した指摘
4. 採用しなかった指摘と理由
5. 最終推奨案
6. 人間が判断すべき事項

--- あなたの初期案 ---
$draft

--- Codexのレビュー ---
$review
"@

& claude -p $finalPrompt | Out-File -Encoding utf8 ".\ai-work\final-answer.md"
if ($LASTEXITCODE -ne 0) { Write-Host "NG: Claude の統合ステップに失敗しました。" -ForegroundColor Red; exit 1 }
Write-Host "保存しました: ai-work\final-answer.md"

# --- 完了 -------------------------------------------------------------------
Write-Host "`n=== 完了 ===" -ForegroundColor Green
Write-Host "生成ファイル:"
Get-ChildItem .\ai-work | Format-Table Name, Length, LastWriteTime
Write-Host "最終案を確認するには: Get-Content .\ai-work\final-answer.md"
