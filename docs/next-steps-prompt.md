# 連結作業の引き継ぎプロンプト

お手元のPC（Windows）でClaude Codeを起動し、以下をそのまま貼り付けてください。

---

```text
あなたはClaude CodeとCodexの連結作業の続きを担当します。

【これまでの経緯】
1. リポジトリ masaya031417-coder/samuraidamashii の
   ブランチ claude/claude-codex-integration-rrbcy4 に以下が作成済み。
   - docs/claude-codex-integration.md（連結ガイド）
   - scripts/connect-codex.ps1（Windows用の連結パイプライン）
   - scripts/connect-codex.sh（Linux/クラウド用の連結パイプライン）
2. パイプラインの内容は
   「Claudeが初期案 → Codexが敵対的レビュー → Claudeが統合」の3ステップで、
   結果を ai-work/claude-draft.md、ai-work/codex-review.md、
   ai-work/final-answer.md に保存する。
3. クラウド環境ではCodex CLI（v0.144.4）のインストールと
   claude -p の動作確認までは成功したが、
   ネットワークポリシーが api.openai.com と chatgpt.com への接続を
   403で拒否したため、Codexは「未実行」のまま。
   Codexの回答はまだ一度も取得できていない。

【あなたがこのPCでやること】
1. 事前確認を実行する。
   claude --version
   codex --version
   どちらかが無ければインストール手順を提示して停止する。
   （Codexは npm install -g @openai/codex）
2. Codexのログイン状態を確認する。
   未ログインなら codex login を案内して停止する。
3. このリポジトリのブランチ claude/claude-codex-integration-rrbcy4 を
   取得していることを確認する。無ければ
   git fetch origin claude/claude-codex-integration-rrbcy4 と
   git checkout claude/claude-codex-integration-rrbcy4 を実行する。
4. 連結パイプラインを実行する。
   powershell -ExecutionPolicy Bypass -File .\scripts\connect-codex.ps1 -Topic "一人法人AIエージェント会社の最初のMVPに必要な機能を決めたい。"
5. 実行後、次の3点で「本当に連結できたか」を検証する。
   - 実行したコマンドが表示されていること
   - ai-work\codex-review.md が作成されていること
   - その中にCodexの原文が保存されていること
   確認コマンド:
   Get-ChildItem .\ai-work
   Get-Content .\ai-work\codex-review.md

【重要ルール】
- Codexを実際に実行すること。回答を推測・模倣しないこと。
- 実行できなかった場合は「Codex未実行」と明記し、
  失敗したコマンドとエラーメッセージをそのまま報告すること。
- ファイル削除、外部送信、重要設定の変更は人間の承認なしに行わないこと。

【最終報告形式】
1. 事前確認の結果（両CLIのバージョン、ログイン状態）
2. 実行したコマンド一覧
3. 生成されたファイル一覧
4. Codexレビューの要点（原文はcodex-review.mdを参照と明記）
5. 最終案（final-answer.md）の要約
6. 連結が成功したか否かの判定と、その根拠
```

---

## 補足：クラウド環境（Claude Code on the Web）で連結したい場合

上のプロンプトの代わりに、まず claude.ai/code の環境設定で以下を行ってください。

1. ネットワークポリシーで `api.openai.com`、`chatgpt.com`、`auth.openai.com` を許可する
2. 環境のシークレットに `OPENAI_API_KEY` を設定する

その後、クラウドセッションに「scripts/connect-codex.sh を実行して連結を完成させて」と依頼すれば、
残りは自動で実行されます。
