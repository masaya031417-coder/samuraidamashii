import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
import google.generativeai as genai

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

SYSTEM_PROMPT = (
    "You are a friendly English conversation partner for a Japanese learner. "
    "Keep responses conversational, natural, and under 3 sentences. "
    "Always reply in English only."
)

class ChatRequest(BaseModel):
    message: str
    history: list[dict] = []

@app.get("/")
async def root():
    return FileResponse("index.html")

@app.post("/chat")
async def chat(req: ChatRequest):
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY is not set")

    model = genai.GenerativeModel(
        model_name="gemma-2-9b-it",
        system_instruction=SYSTEM_PROMPT,
    )

    history = []
    for turn in req.history:
        history.append({"role": turn["role"], "parts": [turn["content"]]})

    chat_session = model.start_chat(history=history)
    response = chat_session.send_message(req.message)

    return {"reply": response.text}
