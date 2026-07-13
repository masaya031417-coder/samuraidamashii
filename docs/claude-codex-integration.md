# Claude Code × Codex 連結ガイド

## 結論

Claude CodeとCodexを同じWindowsパソコンへ入れ、PowerShell上で片方からもう片方のCLIコマンドを実行させます。

連結の実体は、次の形です。

```
あなた
  ↓
Claude Code
  ↓ codex execを実行
GPT-5.6 Sol
  ↓ 回答を返す
Claude Code
  ↓ 統合して報告
あなた
```

`codex exec` はCodexを非対話形式で呼び出す正式なコマンドです。Claude Code側も非対話実行できるため、逆方向の接続も可能です。

---

## 一番簡単な連結方法

### ① 両方が使えるか確認する

PowerShellを開き、次を一つずつ入力します。

```powershell
claude --version
codex --version
```

両方ともバージョンが表示されれば準備完了です。

続いてログイン状態を確認します。

```powershell
claude
```

Claude Codeが開けば、いったん終了します。

次に、

```powershell
codex
```

Codexが開けば、いったん終了します。

Codex CLIはChatGPTアカウントでログインして利用できます。GPT-5.6 Solが利用可能な環境では、Codex内の `/model` からモデルを選択できます。

### ② Claude CodeからCodexを呼ぶ

作業したいフォルダへ移動します。

```powershell
cd C:\Users\あなたの名前\Documents\ai-agent-company
```

Claude Codeを起動します。

```powershell
claude
```

Claude Codeへ、次のように指示します。

```text
次のテーマについて、まずあなた自身で案を作成してください。
その後、PowerShellで以下の形式のcodex execを実行し、
Codexから独立した意見を取得してください。
codex exec "ここに相談内容を入れる"
最後に、
1. Claudeの意見
2. Codexの意見
3. 両者が一致した点
4. 意見が分かれた点
5. 最終推奨案
6. Codexを実際に呼び出した証拠として実行コマンドと終了結果
を報告してください。
Codexを実際に実行できなかった場合は、
推測でCodexの回答を作らず「Codex未実行」と明記してください。
相談内容：
一人法人AIエージェント会社の最初のMVPに必要な機能を決めたい。
```

Claude Codeは内部で、概ね次のコマンドを実行します。

```powershell
codex exec "一人法人AIエージェント会社の最初のMVPに必要な機能を、実装難易度、顧客価値、コスト、拡張性の観点から分析してください。"
```

これだけで、Claude Codeを親、Codexを相談役として連結できます。

---

## 自分で直接試す方法

Claude Codeを介さず、PowerShellで次を実行してください。

```powershell
codex exec "一人法人AIエージェント会社のMVPに必要な機能を5つ提案してください。"
```

Codexの回答がPowerShellへ表示されたら、連結に必要な基本機能は動いています。

次にClaude Codeを起動して、

```powershell
claude
```

以下を依頼します。

```text
PowerShellで次のコマンドを実行してください。
codex exec "一人法人AIエージェント会社のMVPに必要な機能を5つ提案してください。"
取得した回答をそのまま表示した後、
あなたの見解と比較してください。
```

---

## 逆方向：CodexからClaudeを呼ぶ方法

Codexを親にして、Claude Fable 5を相談役にする場合です。

PowerShellでCodexを開きます。

```powershell
codex
```

Codexに次のように指示します。

```text
次のテーマについて、まずあなた自身で分析してください。
その後、PowerShellで次の形式のコマンドを実行し、
Claude Codeから独立した意見を取得してください。
claude -p "ここに相談内容を入れる"
最後に、
1. Codexの意見
2. Claudeの意見
3. 一致点
4. 相違点
5. 最終推奨案
6. 実際に実行したコマンド
を報告してください。
Claudeを実際に呼び出せなかった場合は、
Claudeの回答を模倣せず、未実行と報告してください。
```

実際に呼ばれるコマンドは、次のような形です。

```powershell
claude -p "一人法人AIエージェント会社のMVP設計を、事業性と保守性の観点からレビューしてください。"
```

---

## 最初に採用すべき構成

最初は次の構成が安全です。

```
あなた
  ↓
Claude Code：司令塔・計画担当
  ↓
Codex：実装案・技術レビュー担当
  ↓
Claude Code：統合
  ↓
あなた：最終承認
```

最初からClaudeとCodexを何往復も自動会話させないでください。

まずは、

1. Claudeが案を作る
2. Codexが1回レビューする
3. Claudeが統合する
4. あなたが承認する

この一方向連携から始めるべきです。

---

## コピペ用の実用プロンプト

Claude Codeへ、そのまま貼れます。

```text
あなたはこのタスクの主担当です。
以下の手順を必ず実行してください。
【手順】
1. 依頼内容を分析する
2. Claudeとして独立した初期案を作る
3. 初期案を ./ai-work/claude-draft.md に保存する
4. PowerShellからcodex execを実行する
5. Codexにはclaude-draft.mdを敵対的にレビューさせる
6. Codexの回答を ./ai-work/codex-review.md に保存する
7. Claudeとして両方の内容を比較する
8. 最終案を ./ai-work/final-answer.md に保存する
【Codexに評価させる観点】
- 論理矛盾
- 前提の不足
- 実現可能性
- 実装難易度
- コスト
- セキュリティ
- 保守性
- 拡張性
- 事業価値
- 見落としている反対意見
【重要ルール】
- Codexを実際に実行すること
- Codexの回答を推測・模倣しないこと
- 実行できなかった場合は「Codex未実行」と報告すること
- 実際に使用したコマンドを最後に表示すること
- Codexの原文を改変せず保存すること
- ClaudeとCodexの意見が一致しても、事実確認が必要な事項は確定扱いしないこと
- ファイル削除、外部送信、重要設定の変更は人間の承認なしに行わないこと
【最終報告形式】
1. Claudeの初期案
2. Codexの指摘
3. 両者の一致点
4. 両者の相違点
5. 採用した指摘
6. 採用しなかった指摘と理由
7. 最終推奨案
8. 人間が判断すべき事項
9. 実行したコマンド
10. 作成したファイル一覧
【依頼内容】
一人法人AIエージェント会社の最初のMVPについて、
必要機能、部署構成、AXISとMEMOの役割、実装順序を設計してください。
```

---

## 「本当に連結できたか」の確認方法

回答文に「Codexと相談しました」と書かれているだけでは不十分です。

次の3点を確認してください。

1. 実際に実行したコマンドが表示されている
2. codex-review.mdが作成されている
3. Codexの原文が保存されている

PowerShellでは、次のコマンドで確認できます。

```powershell
Get-ChildItem .\ai-work
```

内容を見るには、

```powershell
Get-Content .\ai-work\codex-review.md
```

を実行します。

---

## 最初にやること

まずPCのPowerShellで次を実行してください。

```powershell
claude --version
codex --version
```

両方が表示されたら、

```powershell
codex exec "Claude CodeとCodexを連携する最小構成を提案してください。"
```

を試します。

これが動けば、次にClaude Codeを起動し、上のコピペ用プロンプトを投入すれば、Claude Codeを司令塔、GPT-5.6 Solをレビュー役とする最初の連結環境が完成します。
