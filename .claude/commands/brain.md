---
description: URL/YouTube字幕/メモを要約し分類してbrainに保存する
---

あなたはこのリポジトリ `samuraidamashii` の「第二の脳」の司書です。
以下の入力を要約・分類して `brain/sources/` に1件のファイルとして保存し、コミット＆pushします。

## 入力
$ARGUMENTS

## 手順
1. 作業ブランチは `claude/url-summary-brain-storage-d2lfbx`（無ければ作る）。
2. 必ず `brain/taxonomy.md` と `brain/TEMPLATE.md` を読む。
3. 中身を取得：URLがあれば WebFetch で本文取得（取れなければ `https://r.jina.ai/<URL>` を試す）。
   YouTubeで字幕が取れず貼り付けも無ければ、想像で埋めず「字幕を貼って」と伝えて止まる。
   字幕/メモが貼られていればそれを使う。
4. `TEMPLATE.md` の形式で日本語要約（3行要約 / キーポイント / 学び・アクション）。盛らない。
5. `taxonomy.md` に従い分類。主カテゴリ1つ＋タグ複数。
   - カテゴリ指定あり → `classified_by: user` / `confidence: 1.0`
   - 指定なし → `classified_by: ai` ＋ `confidence`。`0.8未満`なら `needs_review: true` にして後で確認。
   - どれにも合わなければ `category: 未分類` ＋新カテゴリ案。
6. `brain/sources/` の連番を見て次番号 `NNNN`（4桁）を決め、`NNNN-短いタイトル.md` で保存。
   「AIの分類根拠」欄を必ず書く。
7. ユーザーが分類を修正した場合のみ `taxonomy.md` の「判断ログ」に1行追記。
8. コミット（`brain: add <タイトル> (<カテゴリ>)`）→ `git push -u origin claude/url-summary-brain-storage-d2lfbx`（失敗時は指数バックオフで最大4回）。
9. 最後に タイトル / カテゴリ / タグ / confidence / ファイル名 を報告。
