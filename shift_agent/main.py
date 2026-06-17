"""
main.py - シフト自動登録CLIツールのエントリーポイント

使用例:
  python main.py --file シフト.pdf --name 山本
  python main.py --file スクショ.png
  python main.py --text "勤務日時：2026/06/14(日) 08:00-20:00 場所：GLION ARENA KOBE"
  python main.py --file シフト.pdf --dry-run
  python main.py --delete
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


def format_event_table(events: list[dict]) -> str:
    """
    カレンダーイベントのリストを番号付き表形式で整形する（削除モード用）。
    """
    headers = ["No", "日付", "開始", "終了", "タイトル", "場所"]
    rows = [
        [str(i + 1), e["date"], e["start"], e["end"], e["title"], e["place"]]
        for i, e in enumerate(events)
    ]

    try:
        from tabulate import tabulate
        return tabulate(rows, headers=headers, tablefmt="rounded_outline")
    except ImportError:
        pass

    all_rows = [headers] + rows
    col_widths = [max(len(str(r[i])) for r in all_rows) for i in range(len(headers))]
    sep = "+" + "+".join("-" * (w + 2) for w in col_widths) + "+"
    lines = [sep]
    for idx, row in enumerate(all_rows):
        cells = " | ".join(str(cell).ljust(col_widths[i]) for i, cell in enumerate(row))
        lines.append(f"| {cells} |")
        if idx == 0:
            lines.append(sep)
    lines.append(sep)
    return "\n".join(lines)


def delete_mode() -> None:
    """
    登録済みシフトイベントの一覧を表示し、選択したものを削除するモード。
    使用: python main.py --delete
    """
    try:
        from calendar_push import delete_event, list_shift_events
    except ImportError as e:
        print(f"❌ 必要なライブラリが見つかりません: {e}\n   pip install -r requirements.txt を実行してください。")
        sys.exit(1)

    print("🗓️  登録済みシフトを取得中...")

    try:
        events = list_shift_events()
    except FileNotFoundError:
        sys.exit(1)
    except Exception as e:
        print(f"❌ イベントの取得に失敗しました: {e}")
        sys.exit(1)

    if not events:
        print("⚠️  削除対象のシフトイベントが見つかりませんでした（過去7日〜今後90日）。")
        sys.exit(0)

    print(f"\n📋 {len(events)}件のシフトイベントが見つかりました\n")
    print(format_event_table(events))
    print()

    # 削除する番号を選択
    try:
        raw = input("🗑️  削除する番号を入力（例: 1,3  または  all）[q でキャンセル]: ").strip()
    except (KeyboardInterrupt, EOFError):
        print("\n中断しました。")
        sys.exit(0)

    if raw.lower() == "q" or not raw:
        print("キャンセルしました。")
        sys.exit(0)

    # 削除対象を特定
    if raw.lower() == "all":
        targets = events
    else:
        try:
            indices = [int(n.strip()) - 1 for n in raw.split(",")]
        except ValueError:
            print("❌ 番号の形式が正しくありません。例: 1,3")
            sys.exit(1)

        out_of_range = [i + 1 for i in indices if i < 0 or i >= len(events)]
        if out_of_range:
            print(f"❌ 範囲外の番号が含まれています: {out_of_range}")
            sys.exit(1)

        targets = [events[i] for i in indices]

    # 削除確認
    print(f"\n以下の {len(targets)}件 を削除します:")
    for e in targets:
        place = f"  {e['place']}" if e["place"] else ""
        print(f"  - {e['date']} {e['start']}〜{e['end']}  {e['title']}{place}")

    try:
        confirm = input("\n本当に削除しますか？ [y/N]: ").strip().lower()
    except (KeyboardInterrupt, EOFError):
        print("\n中断しました。")
        sys.exit(0)

    if confirm != "y":
        print("キャンセルしました。")
        sys.exit(0)

    # 削除実行
    success = 0
    for e in targets:
        try:
            delete_event(e["id"])
            print(f"  ✅ 削除完了: {e['date']} {e['start']}〜{e['end']}  {e['title']}")
            success += 1
        except Exception as err:
            print(f"  ❌ 削除失敗: {e['date']} — {err}")

    print(f"\n🗑️  {success}件のイベントを削除しました。")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="シフト表をClaudeで読み取りGoogleカレンダーに自動登録するツール",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "使用例:\n"
            "  python main.py --file シフト.pdf --name 山本\n"
            "  python main.py --file スクショ.png\n"
            '  python main.py --text "勤務日時：2026/06/14(日) 08:00-20:00"\n'
            "  python main.py --file シフト.pdf --dry-run\n"
            "  python main.py --delete"
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
    parser.add_argument(
        "--delete",
        action="store_true",
        help="登録済みシフトの一覧を表示して削除する",
    )

    args = parser.parse_args()

    # --delete モードは他の引数と独立して動作する
    if args.delete:
        delete_mode()
        sys.exit(0)

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
