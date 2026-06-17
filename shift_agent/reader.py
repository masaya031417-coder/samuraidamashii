"""
reader.py - Claude APIを使ってシフト情報を読み取るモジュール
"""

import base64
import json
import re
import sys
from pathlib import Path

import anthropic

# 使用するClaudeモデル
MODEL = "claude-sonnet-4-6"

# シフト記号→時刻の変換表（参考情報としてプロンプトに含める）
SHIFT_SYMBOL_NOTE = (
    "記号変換表：A=09:00-16:00, B=09:00-18:00, C=10:00-18:00, G=変則, "
    "A-13のように数字つきは09:00-13:00。年は2026年。"
)

# 返却JSONの期待スキーマ説明
JSON_SCHEMA_NOTE = (
    '返却形式はJSON配列のみ（説明文不要）。'
    '例：[{"date":"2026-06-21","start":"18:00","end":"23:00","place":"","note":""}]'
)


def _encode_file(file_path: Path) -> str:
    """ファイルをbase64エンコードして返す"""
    with open(file_path, "rb") as f:
        return base64.standard_b64encode(f.read()).decode("utf-8")


def _parse_json_response(text: str) -> list[dict]:
    """
    Claude の応答テキストからJSON配列を抽出・パースする。
    マークダウンコードブロックが含まれる場合も処理する。
    """
    # コードブロック（```json ... ``` または ``` ... ```）を除去
    cleaned = re.sub(r"```(?:json)?\s*", "", text).replace("```", "").strip()

    # JSON配列部分だけ抽出
    match = re.search(r"\[.*\]", cleaned, re.DOTALL)
    if not match:
        print("❌ JSONの抽出に失敗しました。Claudeの応答：")
        print(text)
        sys.exit(1)

    try:
        return json.loads(match.group())
    except json.JSONDecodeError as e:
        print(f"❌ JSONのパースに失敗しました: {e}")
        print("Claude応答（抽出部分）：", match.group()[:500])
        sys.exit(1)


def read_pdf(file_path: Path, name: str = "山本") -> list[dict]:
    """
    PDFのシフト表から指定した名前の勤務情報を抽出する。
    documentブロックを使ってPDFをそのままAPIに送信。
    """
    client = anthropic.Anthropic()

    # PDFをbase64エンコード
    pdf_data = _encode_file(file_path)

    prompt = (
        f"このPDFのシフト表から{name}の行を探し、勤務記号を日付・時刻に変換して"
        f"JSON配列のみ返せ。{SHIFT_SYMBOL_NOTE}{JSON_SCHEMA_NOTE}"
    )

    message = client.messages.create(
        model=MODEL,
        max_tokens=2048,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "document",
                        "source": {
                            "type": "base64",
                            "media_type": "application/pdf",
                            "data": pdf_data,
                        },
                    },
                    {
                        "type": "text",
                        "text": prompt,
                    },
                ],
            }
        ],
    )

    return _parse_json_response(message.content[0].text)


def read_image(file_path: Path) -> list[dict]:
    """
    シフト確認画面のスクリーンショットから○印の行を抽出する。
    imageブロックを使って画像をAPIに送信。
    """
    client = anthropic.Anthropic()

    # 拡張子からMIMEタイプを判定
    ext = file_path.suffix.lower()
    media_type_map = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".gif": "image/gif",
        ".webp": "image/webp",
    }
    media_type = media_type_map.get(ext)
    if not media_type:
        print(f"❌ 未対応の画像形式です: {ext}")
        sys.exit(1)

    # 画像をbase64エンコード
    image_data = _encode_file(file_path)

    prompt = (
        "このシフト確認画面から○がついている行の日付と勤務時間を抽出し"
        f"JSON配列のみ返せ。{JSON_SCHEMA_NOTE}"
    )

    message = client.messages.create(
        model=MODEL,
        max_tokens=2048,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": image_data,
                        },
                    },
                    {
                        "type": "text",
                        "text": prompt,
                    },
                ],
            }
        ],
    )

    return _parse_json_response(message.content[0].text)


def read_text(text: str) -> list[dict]:
    """
    採用メール文などのテキストから勤務日時・場所を抽出する。
    """
    client = anthropic.Anthropic()

    prompt = (
        f"このテキストから勤務日時・場所を抽出しJSON配列のみ返せ。"
        f"{JSON_SCHEMA_NOTE}\n\n---\n{text}"
    )

    message = client.messages.create(
        model=MODEL,
        max_tokens=2048,
        messages=[
            {
                "role": "user",
                "content": prompt,
            }
        ],
    )

    return _parse_json_response(message.content[0].text)


def read_shift(
    file_path: Path | None = None,
    text: str | None = None,
    name: str = "山本",
) -> list[dict]:
    """
    ファイルまたはテキストの種別を自動判別してシフト情報を抽出する。
    返り値：[{"date":"2026-06-21","start":"18:00","end":"23:00","place":"","note":""}]
    """
    if text is not None:
        return read_text(text)

    if file_path is None:
        print("❌ --file または --text のいずれかを指定してください。")
        sys.exit(1)

    if not file_path.exists():
        print(f"❌ ファイルが見つかりません: {file_path}")
        sys.exit(1)

    ext = file_path.suffix.lower()

    if ext == ".pdf":
        return read_pdf(file_path, name=name)
    elif ext in (".png", ".jpg", ".jpeg", ".gif", ".webp"):
        return read_image(file_path)
    else:
        print(f"❌ 未対応のファイル形式です: {ext}（対応：pdf / png / jpg / jpeg）")
        sys.exit(1)
