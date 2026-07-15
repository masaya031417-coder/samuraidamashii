#!/usr/bin/env bash
# Claude Code × Codex 連結パイプライン（Linux / macOS / クラウド環境用）
#
# 使い方:
#   bash scripts/connect-codex.sh "相談したい内容"
#
# 前提:
#   - claude と codex の両CLIがインストール・ログイン済みであること
#   - クラウド環境の場合、ネットワークポリシーで api.openai.com / chatgpt.com /
#     auth.openai.com への接続が許可されていること
#
# 流れ:
#   1. Claude Code (claude -p) が初期案を作成 → ai-work/claude-draft.md
#   2. Codex (codex exec) が敵対的レビュー   → ai-work/codex-review.md
#   3. Claude Code が両者を統合した最終案     → ai-work/final-answer.md

set -euo pipefail

TOPIC="${1:-一人法人AIエージェント会社の最初のMVPに必要な機能を決めたい。}"

echo "=== 事前確認 ==="
command -v claude >/dev/null || { echo "NG: claude が見つかりません"; exit 1; }
command -v codex  >/dev/null || { echo "NG: codex が見つかりません (npm install -g @openai/codex)"; exit 1; }
echo "OK: Claude Code $(claude --version)"
echo "OK: Codex $(codex --version)"

mkdir -p ai-work

echo ""
echo "=== ステップ1: Claude が初期案を作成 ==="
claude -p "次のテーマについて、あなた自身の独立した初期案を作成してください。
Markdown形式で、結論・理由・具体的な構成の順に書いてください。
テーマ: ${TOPIC}" > ai-work/claude-draft.md
echo "保存しました: ai-work/claude-draft.md"

echo ""
echo "=== ステップ2: Codex がレビュー ==="
codex exec "以下はClaudeが作成した初期案です。敵対的レビュアーとして、
論理矛盾・前提の不足・実現可能性・実装難易度・コスト・セキュリティ・
保守性・拡張性・事業価値・見落としている反対意見 の観点から指摘してください。

--- 初期案ここから ---
$(cat ai-work/claude-draft.md)
--- 初期案ここまで ---" > ai-work/codex-review.md || {
  echo "NG: Codex未実行（codex exec が失敗しました）。ログインや通信環境を確認してください。"
  exit 1
}
echo "保存しました: ai-work/codex-review.md"

echo ""
echo "=== ステップ3: Claude が統合 ==="
claude -p "あなたの初期案と、Codexによるレビューを比較し、最終推奨案をまとめてください。
報告形式:
1. 両者の一致点
2. 両者の相違点
3. 採用した指摘
4. 採用しなかった指摘と理由
5. 最終推奨案
6. 人間が判断すべき事項

--- あなたの初期案 ---
$(cat ai-work/claude-draft.md)

--- Codexのレビュー ---
$(cat ai-work/codex-review.md)" > ai-work/final-answer.md
echo "保存しました: ai-work/final-answer.md"

echo ""
echo "=== 完了 ==="
ls -la ai-work/
echo "最終案を確認するには: cat ai-work/final-answer.md"
