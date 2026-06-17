# ShiftApp - iOS シフト自動登録アプリ

音声・PDF・画像・テキストからシフトを読み取り、Googleカレンダーに自動登録するiOSアプリです。  
バックエンドに `shift_agent/server.py`（FastAPI）を使用します。

---

## 全体構成

```
samuraidamashii/
├── shift_agent/          # Pythonバックエンド（FastAPI）
│   ├── server.py         # APIサーバー（新規追加）
│   ├── reader.py         # Claude APIでシフト解析
│   └── ...
└── ShiftApp/             # iOSアプリ（SwiftUI）
    └── ShiftApp/
        ├── ShiftApp.swift
        ├── Models/
        ├── Services/
        ├── Views/
        └── Intents/      # Siriショートカット
```

---

## セットアップ

### 1. バックエンドを起動する

```bash
cd shift_agent
pip install -r requirements.txt
export ANTHROPIC_API_KEY="sk-ant-xxxxxxxx"
uvicorn server:app --host 0.0.0.0 --port 8000 --reload
```

実機からアクセスする場合は `--host` に Mac の LAN IP を指定してください。

### 2. Xcode プロジェクトを作成する

1. Xcode を開き「Create New Project」→「iOS」→「App」を選択
2. Product Name: `ShiftApp`、Interface: `SwiftUI`、Language: `Swift` に設定
3. `ShiftApp/` フォルダ内の Swift ファイルをすべてプロジェクトに追加（ドラッグ＆ドロップ）
4. `Info.plist` の内容を Xcode の Info タブに反映する（下記参照）

### 3. GoogleSignIn SDK を追加する

1. Xcode メニュー「File」→「Add Package Dependencies」を開く
2. URL `https://github.com/google/GoogleSignIn-iOS` を入力して追加
3. `GoogleSignIn` と `GoogleSignInSwift` の両方をターゲットに追加

### 4. Google Cloud Console でOAuth クライアントIDを取得する

1. [Google Cloud Console](https://console.cloud.google.com/) でプロジェクトを作成
2. 「APIとサービス」→「ライブラリ」→「Google Calendar API」を有効化
3. 「APIとサービス」→「認証情報」→「OAuth クライアント ID を作成」を選択
4. アプリケーションの種類で **「iOS」** を選択し、バンドルID（例：`com.yourname.ShiftApp`）を入力
5. 作成されたクライアントIDをコピーして `Info.plist` の2箇所に貼り付ける

```xml
<!-- YOUR_CLIENT_ID の部分を置き換える -->
<key>GIDClientID</key>
<string>123456789-abc.apps.googleusercontent.com</string>

<key>CFBundleURLSchemes</key>
<array>
  <string>com.googleusercontent.apps.123456789-abc</string>
</array>
```

### 5. Info.plist に権限説明を追加する

Xcode の Info タブに以下のキーを追加します。

| Key | Value |
|-----|-------|
| Privacy - Microphone Usage Description | 音声でシフト情報を入力するためにマイクを使用します |
| Privacy - Speech Recognition Usage Description | 話した内容をテキストに変換してシフト情報を読み取るために使用します |

### 6. バックエンドURLを設定する（実機テスト時）

シミュレータ以外の実機でテストする場合は `APIService.swift` の `baseURL` を  
Mac の LAN IP（例：`http://192.168.1.10:8000`）に変更してください。

---

## 機能一覧

| 機能 | 説明 |
|------|------|
| 音声入力 | 「6月21日18時から23時」と話すだけでシフトを解析・登録 |
| Siriショートカット | 「シフトを登録」と Siri に話しかけてアプリを開かずに登録 |
| PDF読み込み | シフト表PDFをファイルピッカーで選択して解析 |
| 画像読み込み | スクリーンショットから○印のシフトを自動抽出 |
| テキスト入力 | メール文を貼り付けて勤務日時・場所を抽出 |
| Googleカレンダー連携 | OAuth2でサインインして直接カレンダーに登録 |

---

## Siriショートカットの設定方法

1. iPhoneの「設定」→「Siri と検索」→「ショートカット」を開く
2. 「シフトを登録」が表示されるのでタップして録音フレーズを設定
3. 以後「Hey Siri、シフトを登録」と言うだけで起動

---

## 変則シフト（G記号）について

G記号のシフトは勤務時間が不規則なため自動登録されません。  
結果画面で警告として表示されますので、手動でカレンダーに追加してください。

---

## 注意事項

- バックエンド（`server.py`）が起動していないとアプリはシフトを解析できません
- `ANTHROPIC_API_KEY` 環境変数がサーバー側に設定されている必要があります
- ローカルネットワーク経由で通信するため、iPhoneと Mac が同一Wi-Fiに接続されている必要があります
- 本番運用する場合はバックエンドをHTTPS対応のサーバーにデプロイしてください
