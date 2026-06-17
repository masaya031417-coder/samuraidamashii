"""
main.py - シフト自動登録CLIツールのエントリーポイント

使用例:
  python main.py --file シフト.pdf --name 山本
  python main.py --file スクショ.png
  python main.py --text "勤務日時：2026/06/14(日) 08:00-20:00 場所：GLION ARENA KOBE"
  python main.py --file シフト.pdf --dry-run
"""

import argparse
import sys
from pathlib import Path

from reader import read_shift


def format_table(shifts: list[dict]) -> str:
    """
    シフトのリストをターミナル表示用の表形式文字列に整形する。
    tabulateが利用できない環境でも動作するよう手動整形。
    """
    # ヘッダー行
    headers = ["日付", "開始", "終了", "場所", "備考"]

    # 各行のデータを文字列化
    rows = []
    for s in shifts:
        rows.append([
            s.get("date", ""),
            s.get("start", ""),
            s.get("end", ""),
            s.get("place", ""),
            s.get("note", ""),
        ])

    # tabulateが使える場合はそちらを優先
    try:
        from tabulate import tabulate
        return tabulate(rows, headers=headers, tablefmt="rounded_outline")
    except ImportError:
        pass

    # tabulate非インストール時のフォールバック手動整形
    all_rows = [headers] + rows
    col_widths = [
        max(len(str(row[i])) for row in all_rows)
        for i in range(len(headers))
    ]

    sep = "+" + "+".join("-" * (w + 2) for w in col_widths) + "+"
    lines = [sep]

    for idx, row in enumerate(all_rows):
        cells = " | ".join(str(cell).ljust(col_widths[i]) for i, cell in enumerate(row))
        lines.append(f"| {cells} |")
        if idx == 0:
            lines.append(sep)  # ヘッダー後に区切り線

    lines.append(sep)
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="シフト表をClaudeで読み取りGoogleカレンダーに自動登録するツール",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "使用例:\n"
            "  python main.py --file シフト.pdf --name 山本\n"
            "  python main.py --file スクショ.png\n"
            '  python main.py --text "勤務日時：2026/06/14(日) 08:00-20:00"\n'
            "  python main.py --file シフト.pdf --dry-run"
        ),
    )

    parser.add_argument(
        "--file",
        type=Path,
        help="読み取るPDF・PNG・JPGファイルのパス",
    )
    parser.add_argument(
        "--text",
        type=str,
        help="メール文などのテキストを直接入力",
    )
    parser.add_argument(
        "--name",
        type=str,
        default="山本",
        help="PDF読み取り時に検索する名前（デフォルト：山本）",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="カレンダー登録せず抽出結果だけ表示する",
    )

    args = parser.parse_args()

    # --file と --text が両方未指定の場合はエラー
    if args.file is None and args.text is None:
        print("❌ --file または --text のいずれかを指定してください。")
        parser.print_help()
        sys.exit(1)

    # ---- Step 1: 読み取り開始メッセージ ----
    print("📄 読み取り中...")

    # ---- Step 2: Claude APIで読み取り ----
    shifts = read_shift(
        file_path=args.file,
        text=args.text,
        name=args.name,
    )

    if not shifts:
        print("⚠️  シフト情報が検出されませんでした。")
        sys.exit(0)

    # ---- Step 3: 抽出結果を表形式で表示 ----
    print(f"\n✅ {len(shifts)}件のシフトを検出しました\n")
    print(format_table(shifts))
    print()

    # --dry-run の場合はここで終了
    if args.dry_run:
        print("🔍 --dry-run モードのため、カレンダー登録はスキップしました。")
        sys.exit(0)

    # ---- Step 4: カレンダー登録の確認 ----
    try:
        answer = input("📅 カレンダーに登録しますか？ [y/N]: ").strip().lower()
    except (KeyboardInterrupt, EOFError):
        print("\n中断しました。")
        sys.exit(0)

    if answer != "y":
        print("キャンセルしました。")
        sys.exit(0)

    # ---- Step 5: Googleカレンダーに登録 ----
    print("\n🗓️  Googleカレンダーに登録しています...")

    # calendar_push はオプション依存のため遅延インポート
    try:
        from calendar_push import push_shifts
    except ImportError as e:
        print(
            f"❌ カレンダー登録に必要なライブラリが見つかりません: {e}\n"
            "   pip install -r requirements.txt を実行してください。"
        )
        sys.exit(1)

    try:
        count = push_shifts(shifts)
    except FileNotFoundError:
        # credentials.json 未配置の場合は calendar_push 内で詳細メッセージ表示済み
        sys.exit(1)
    except Exception as e:
        print(f"❌ カレンダー登録中にエラーが発生しました: {e}")
        sys.exit(1)

    print(f"\n🎉 {count}件のシフトをGoogleカレンダーに登録しました！")


if __name__ == "__main__":
    main()
