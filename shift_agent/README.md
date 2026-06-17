# シフト自動登録ツール

シフト表（PDF）・スクリーンショット（画像）・採用メール文（テキスト）から勤務予定を読み取り、Googleカレンダーに自動登録するCLIツールです。

---

## セットアップ

### 1. 依存ライブラリのインストール

```bash
pip install -r requirements.txt
```

### 2. ANTHROPIC_API_KEY の設定

Claude API を使用するため、Anthropic の API キーを環境変数に設定してください。

**macOS / Linux:**
```bash
export ANTHROPIC_API_KEY="sk-ant-xxxxxxxxxxxxxxxx"
```

永続的に設定する場合は `~/.zshrc` または `~/.bashrc` に上記の行を追加してください。

**Windows (PowerShell):**
```powershell
$env:ANTHROPIC_API_KEY = "sk-ant-xxxxxxxxxxxxxxxx"
```

API キーは [Anthropic Console](https://console.anthropic.com/) で取得できます。

### 3. Google Calendar API の認証設定

Googleカレンダーへの書き込みには OAuth2 認証が必要です。以下の手順で `credentials.json` を取得してください。

**手順：**

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセスし、Googleアカウントでログインします。

2. 画面上部の「プロジェクトを選択」をクリックし、「新しいプロジェクト」でプロジェクトを作成します（名前は任意）。

3. 左メニューから「APIとサービス」→「ライブラリ」を選択し、「Google Calendar API」を検索して「有効にする」をクリックします。

4. 左メニューから「APIとサービス」→「認証情報」を選択し、「認証情報を作成」→「OAuth クライアント ID」をクリックします。

5. 「同意画面の設定」を求められた場合は「外部」を選択し、必須項目（アプリ名・サポートメール）を入力して保存します。テストユーザーとして自分のGmailアドレスを追加してください。

6. アプリケーションの種類は「デスクトップアプリ」を選択し、名前を入力して「作成」をクリックします。

7. 作成されたクライアント ID の右にあるダウンロードボタン（↓）をクリックし、JSONファイルをダウンロードします。

8. ダウンロードしたファイルを `credentials.json` にリネームし、このツールのディレクトリ（`main.py` と同じ場所）に配置します。

初回実行時にブラウザが自動で開き、Googleアカウントでの許可を求めます。許可すると `token.json` が生成され、以降は自動認証されます。

---

## 使用例

### PDF のシフト表から読み取り（名前指定）

```bash
python main.py --file シフト.pdf --name 山本
```

シフト表のPDFから「山本」の行を探し、勤務記号（A/B/C など）を時刻に変換してカレンダーに登録します。

### スクリーンショットから読み取り

```bash
python main.py --file スクショ.png
```

シフト確認画面のスクリーンショットから○印がついている行の日付・時刻を抽出して登録します。

### メール文などのテキストから読み取り

```bash
python main.py --text "勤務日時：2026/06/14(日) 08:00-20:00 場所：GLION ARENA KOBE"
```

採用メールなどのテキストを直接貼り付けて勤務情報を抽出・登録します。

### 登録前に内容を確認する（ドライラン）

```bash
python main.py --file シフト.pdf --dry-run
```

`--dry-run` を付けると抽出結果だけ表示し、カレンダーへの登録は行いません。

---

## シフト記号の対応表

| 記号 | 勤務時間 |
|------|----------|
| A | 09:00〜16:00 |
| B | 09:00〜18:00 |
| C | 10:00〜18:00 |
| G | **変則（要確認）** |
| A-13 など数字付き | 09:00〜13:00（開始は記号の時刻、終了は数字） |

## 変則シフト（G）について

シフト記号が「G」の場合、勤務時間が不規則なためカレンダーへの自動登録はスキップされます。
ツール実行時に警告が表示されますので、該当日は手動でカレンダーを確認・登録してください。

---

## ファイル構成

```
shift_agent/
├── main.py           # CLIエントリーポイント
├── reader.py         # Claude APIによるシフト読み取り
├── calendar_push.py  # Googleカレンダー登録
├── requirements.txt  # 依存ライブラリ
├── README.md         # このファイル
├── credentials.json  # Google OAuth2認証情報（自分で配置）
└── token.json        # 認証トークンキャッシュ（自動生成）
```

`credentials.json` と `token.json` には認証情報が含まれるため、Gitリポジトリへのコミットは避けてください。
