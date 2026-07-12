# AI会社チーム Web（Python版・インストール不要）

11人のAIキャラクターが議論するWebアプリ。
**Flask等の追加インストール不要** — Python本体と `claude` コマンド（Claude Code）だけで動きます。
APIキーも不要（Claude Codeのログイン＝Proサブスクで動作）。

## セットアップ（3ステップ）

1. **ファイルを配置**
   `app.py` と `AI_Team_Web.vbs` を `C:\Users\masay\AITeamWeb\` に置く。

2. **Claude Code が入っているか確認**
   コマンドプロンプトで `claude --version` が動けばOK。
   （未インストールなら `npm install -g @anthropic-ai/claude-code`）

3. **`AI_Team_Web.vbs` をダブルクリック**
   → サーバーが起動してブラウザが開きます。

## うまくいかないとき

「could not start」が出たら、コマンドプロンプトで直接起動してエラーを確認：

```cmd
"C:\Users\masay\AppData\Local\Programs\Python\Python310\python.exe" "C:\Users\masay\AITeamWeb\app.py"
```

- 赤いエラーが出る → その内容を確認
- `🚀 起動！` と出て `http://localhost:5000` が開ければ成功

## スマホから使う

同じWiFiなら、サーバー起動中にスマホのブラウザで
`http://（PCのIPアドレス）:5000` を開く。
音声入力（🎤）・読み上げ（🔊）にも対応。

## 中身

- `app.py` … Python標準ライブラリのみのWebサーバー（SSEストリーミング）
- `AI_Team_Web.vbs` … ダブルクリック用ランチャー
- `requirements.txt` … 依存なし（説明のみ）
