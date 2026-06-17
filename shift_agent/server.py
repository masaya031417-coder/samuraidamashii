"""
server.py - iOSアプリ向けFastAPIバックエンド

起動方法:
  uvicorn server:app --host 0.0.0.0 --port 8000 --reload
"""

import tempfile
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from reader import read_shift

app = FastAPI(title="ShiftAgent API", description="シフト解析APIサーバー")

# iOSシミュレータ・実機・ローカル開発からのリクエストをすべて許可
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    """ヘルスチェック用エンドポイント（アプリ起動確認に使用）"""
    return {"status": "ok"}


@app.post("/parse")
async def parse_shift_endpoint(
    file: Optional[UploadFile] = File(None),
    text: Optional[str] = Form(None),
    name: str = Form("山本"),
):
    """
    ファイル（PDF/画像）またはテキストからシフト情報を抽出して返す。

    Returns:
        {"shifts": [{"date":"...","start":"...","end":"...","place":"","note":""}]}
    """
    if text:
        shifts = read_shift(text=text)
        return {"shifts": shifts}

    if file is None:
        raise HTTPException(status_code=400, detail="file または text を指定してください")

    # 拡張子を保持した一時ファイルに保存して reader に渡す
    suffix = Path(file.filename or "upload.bin").suffix.lower()
    contents = await file.read()

    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(contents)
        tmp_path = Path(tmp.name)

    try:
        shifts = read_shift(file_path=tmp_path, name=name)
    finally:
        # 一時ファイルを確実に削除
        tmp_path.unlink(missing_ok=True)

    return {"shifts": shifts}
