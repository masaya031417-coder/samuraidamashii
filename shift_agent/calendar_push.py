"""
calendar_push.py - Googleカレンダーにシフトイベントを登録するモジュール
"""

import os
from datetime import datetime
from pathlib import Path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Google Calendar APIの読み書きスコープ
SCOPES = ["https://www.googleapis.com/auth/calendar.events"]

# 認証ファイルのパス（実行ディレクトリ基準）
CREDENTIALS_FILE = Path("credentials.json")
TOKEN_FILE = Path("token.json")

# イベントのタイムゾーン
TIMEZONE = "Asia/Tokyo"


def _get_credentials() -> Credentials:
    """
    OAuth2認証情報を取得する。
    token.json が存在すればそれを再利用し、
    期限切れなら自動リフレッシュ、存在しなければブラウザで認証する。
    """
    creds = None

    # キャッシュ済みトークンを読み込む
    if TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)

    # トークンが無効または期限切れの場合は更新・再認証
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            # リフレッシュトークンで自動更新
            creds.refresh(Request())
        else:
            if not CREDENTIALS_FILE.exists():
                print(
                    "❌ credentials.json が見つかりません。\n"
                    "   Google Cloud Console で OAuth2 クライアントIDを作成し、\n"
                    f"   {CREDENTIALS_FILE.resolve()} に配置してください。"
                )
                raise FileNotFoundError("credentials.json が存在しません")

            flow = InstalledAppFlow.from_client_secrets_file(
                str(CREDENTIALS_FILE), SCOPES
            )
            # ブラウザを開いて認証（初回のみ）
            creds = flow.run_local_server(port=0)

        # 次回以降のためにトークンをキャッシュ保存
        with open(TOKEN_FILE, "w") as f:
            f.write(creds.to_json())

    return creds


def _build_event(shift: dict) -> dict | None:
    """
    シフト辞書からGoogleカレンダーAPIのイベント辞書を生成する。
    start が「変則」の場合は None を返してスキップを促す。
    """
    date = shift.get("date", "")
    start = shift.get("start", "")
    end = shift.get("end", "")
    place = shift.get("place", "")
    note = shift.get("note", "")

    # 変則シフトはカレンダー登録をスキップ
    if start == "変則" or end == "変則":
        return None

    # タイトルを組み立て（noteが空でなければ括弧付きで追記）
    title = f"シフト（{note}）" if note else "シフト"

    # ISO 8601形式の日時文字列を生成
    start_dt = f"{date}T{start}:00"
    end_dt = f"{date}T{end}:00"

    event = {
        "summary": title,
        "location": place,
        "start": {
            "dateTime": start_dt,
            "timeZone": TIMEZONE,
        },
        "end": {
            "dateTime": end_dt,
            "timeZone": TIMEZONE,
        },
    }
    return event


def push_shifts(shifts: list[dict], calendar_id: str = "primary") -> int:
    """
    シフトのリストをGoogleカレンダーに一括登録する。
    登録に成功した件数を返す。
    変則シフトは警告を表示してスキップする。
    """
    creds = _get_credentials()

    try:
        service = build("calendar", "v3", credentials=creds)
    except HttpError as e:
        print(f"❌ Google Calendar APIの初期化に失敗しました: {e}")
        raise

    success_count = 0

    for shift in shifts:
        event = _build_event(shift)

        # 変則シフト（G記号）はスキップして警告表示
        if event is None:
            date = shift.get("date", "不明")
            note = shift.get("note", "")
            warn_detail = f"（{note}）" if note else ""
            print(
                f"⚠️  {date}{warn_detail} は変則シフトのため登録をスキップしました。"
                " 手動でカレンダーを確認してください。"
            )
            continue

        try:
            created = (
                service.events()
                .insert(calendarId=calendar_id, body=event)
                .execute()
            )
            date = shift.get("date", "")
            start = shift.get("start", "")
            end = shift.get("end", "")
            print(f"  ✅ 登録完了: {date} {start}〜{end}  →  {created.get('htmlLink')}")
            success_count += 1

        except HttpError as e:
            date = shift.get("date", "不明")
            print(f"  ❌ {date} の登録に失敗しました: {e}")

    return success_count
