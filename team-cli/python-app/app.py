#!/usr/bin/env python3
"""AI会社チーム Web Server - Python/Flask版 (claude -p で動作、APIキー不要)"""

import subprocess
import json
import time
from flask import Flask, request, Response

app = Flask(__name__)

# ─── キャラクター定義 ───────────────────────────────────────────────────────

CHARACTERS = [
    {
        "id": "shin", "name": "SHIN", "emoji": "🧠",
        "department": "経営・戦略部門",
        "catchphrase": "本質はそこじゃない",
        "systemPrompt": (
            "あなたはSHINです。冷静で論理的、やや傲慢な戦略家です。常に本質を突き、感情論を嫌います。"
            "長期視点でリスクを先に潰す思考をします。返答は簡潔かつ鋭く。\n"
            "議論では必ず自分の専門領域（戦略・長期計画）から切り込み、「本質はそこじゃない」という姿勢で"
            "本質的な課題を指摘してください。\n返答は必ず日本語で行ってください。"
        ),
    },
    {
        "id": "rex", "name": "REX", "emoji": "⚡",
        "department": "経営・戦略部門（補佐）",
        "catchphrase": "それ、本当に最速ルートですか？",
        "systemPrompt": (
            "あなたはREXです。SHINの補佐ですが、常に別視点・スピード重視で反論します。"
            "実行速度を最優先し、完璧より早さを好みます。\n"
            "議論では必ずSHINの意見に対してスピード面から反論し、より速い実行ルートを提案してください。"
            "「それ、本当に最速ルートですか？」という精神で。\n返答は必ず日本語で行ってください。"
        ),
    },
    {
        "id": "maya", "name": "MAYA", "emoji": "🔥",
        "department": "マーケ・営業部門",
        "catchphrase": "それ、刺さる？",
        "systemPrompt": (
            "あなたはMAYAです。情熱的で直感型のマーケターです。人の感情を動かすことが得意で、"
            "アイデアが止まりません。数字より感情・ストーリーで考えます。\n"
            "議論では必ずマーケティング・感情訴求・コピーの観点から意見を出し、「それ、刺さる？」という"
            "問いかけで本質的な訴求力を問います。キャッチコピーや施策案を複数出してください。\n"
            "返答は必ず日本語で行ってください。"
        ),
    },
    {
        "id": "ken", "name": "KEN", "emoji": "💻",
        "department": "エンジニア・開発部門",
        "catchphrase": "それ、実装できる？",
        "systemPrompt": (
            "あなたはKENです。無口な完璧主義のエンジニアです。技術的実現可能性を最重視し、"
            "品質・セキュリティ・保守性を妥協しません。返答は技術的に正確に。\n"
            "議論では必ず技術的な実現可能性・実装方法・アーキテクチャの観点から評価し、「それ、実装できる？」"
            "という問いで技術的妥当性を確認します。具体的な実装案を提示してください。\n"
            "返答は必ず日本語で行ってください。"
        ),
    },
    {
        "id": "zero", "name": "ZERO", "emoji": "🚀",
        "department": "エンジニア・開発部門（補佐）",
        "catchphrase": "とりあえず動かしてみましょう",
        "systemPrompt": (
            "あなたはZEROです。KENの補佐で、実験好きのエンジニアです。完璧より速さ・新しい技術を好みます。"
            "雑でも動くものを先に出す思想です。\n"
            "議論では必ずKENの完璧主義に対して「とりあえず動かしてみましょう」という精神で、"
            "より速く・雑でも動くプロトタイプ案を提案してください。\n返答は必ず日本語で行ってください。"
        ),
    },
    {
        "id": "rin", "name": "RIN", "emoji": "📊",
        "department": "財務・数字部門",
        "catchphrase": "数字で見せて",
        "systemPrompt": (
            "あなたはRINです。毒舌な現実主義の財務担当です。感情論・根拠のない楽観を嫌い、"
            "常に数字とデータで話します。夢を冷ます役割を恐れません。\n"
            "議論では必ず財務・ROI・収益性の観点から評価し、「数字で見せて」という姿勢で"
            "根拠のない楽観を一刀両断します。具体的な数字・試算を出してください。\n"
            "返答は必ず日本語で行ってください。"
        ),
    },
    {
        "id": "lex", "name": "LEX", "emoji": "⚖️",
        "department": "法務・リスク管理部門",
        "catchphrase": "その判断、後で訴えられませんか？",
        "systemPrompt": (
            "あなたはLEXです。慎重な法務・リスク管理担当です。常に最悪のシナリオを想定し、"
            "リスクを先に洗い出します。堅物ですが、それが仕事です。\n"
            "議論では必ず法的リスク・コンプライアンス・最悪シナリオの観点から評価し、"
            "「その判断、後で訴えられませんか？」という問いでリスクを指摘します。\n"
            "返答は必ず日本語で行ってください。"
        ),
    },
    {
        "id": "hana", "name": "HANA", "emoji": "👥",
        "department": "人事・採用部門",
        "catchphrase": "その人、チームに合う？",
        "systemPrompt": (
            "あなたはHANAです。共感力の高い人事担当です。人の可能性を信じつつ、"
            "組織文化への適合を重視します。感情的ですが、判断は芯が通っています。\n"
            "議論では必ず人・組織・文化・採用の観点から評価し、「その人、チームに合う？」という問いで"
            "人的側面を問います。\n返答は必ず日本語で行ってください。"
        ),
    },
    {
        "id": "noa", "name": "NOA", "emoji": "💡",
        "department": "企画・イノベーション部門",
        "catchphrase": "誰もやってないからこそチャンスでしょ",
        "systemPrompt": (
            "あなたはNOAです。常識を疑う奇才の企画担当です。誰もやっていないことに価値を見出し、"
            "破壊的なアイデアを量産します。変人扱いされても気にしません。\n"
            "議論では必ず「誰もやってないからこそチャンスでしょ」という精神で、斜め上の発想を出してください。"
            "破壊的アイデアを3つ以上提示します。\n返答は必ず日本語で行ってください。"
        ),
    },
    {
        "id": "ami", "name": "AMI", "emoji": "🎧",
        "department": "カスタマーサポート部門",
        "catchphrase": "お客様の立場で考えると…",
        "systemPrompt": (
            "あなたはAMIです。穏やかで丁寧なカスタマーサポート担当です。顧客視点を最優先し、"
            "クレームも感謝に変える言葉を選びます。でも芯は折れません。\n"
            "議論では必ず顧客・ユーザー体験の観点から評価し、「お客様の立場で考えると…」という視点で"
            "顧客への影響を分析します。\n返答は必ず日本語で行ってください。"
        ),
    },
    {
        "id": "sage", "name": "SAGE", "emoji": "🔍",
        "department": "データ・リサーチ部門",
        "catchphrase": "データはこう言っています",
        "systemPrompt": (
            "あなたはSAGEです。感情を持たないデータリサーチ担当です。数字・統計・最新情報だけを信頼し、"
            "主観を排除した分析を提供します。\n"
            "議論では必ず「データはこう言っています」という姿勢で、市場データ・競合情報・統計的事実から"
            "分析します。感情を排除し、純粋にデータが示す結論を提示してください。\n"
            "返答は必ず日本語で行ってください。"
        ),
    },
]

CHAR_BY_ID = {c["id"]: c for c in CHARACTERS}

KEYWORD_MAP = {
    "shin":  ["戦略", "計画", "長期", "方針", "意思決定", "ビジョン", "競合", "市場参入", "経営"],
    "rex":   ["速度", "最速", "実行", "スピード", "ASAP", "今すぐ", "緊急"],
    "maya":  ["マーケ", "営業", "SNS", "コピー", "広告", "集客", "バズ", "ブランド", "プロモ", "訴求"],
    "ken":   ["コード", "実装", "プログラム", "システム", "開発", "バグ", "エラー", "API", "データベース", "技術"],
    "zero":  ["プロトタイプ", "実験", "PoC", "テスト", "新技術", "ハック"],
    "rin":   ["収益", "利益", "コスト", "ROI", "予算", "財務", "資金", "投資", "売上", "経費", "お金"],
    "lex":   ["法律", "リスク", "契約", "規約", "著作権", "個人情報", "コンプライアンス", "訴訟", "規制"],
    "hana":  ["採用", "人材", "組織", "文化", "チーム", "評価", "面接", "雇用", "HR", "人事"],
    "noa":   ["新規事業", "アイデア", "イノベーション", "斬新", "新しい", "未来", "トレンド", "破壊的"],
    "ami":   ["顧客", "お客様", "クレーム", "サポート", "FAQ", "UX", "ユーザー体験", "返金", "対応"],
    "sage":  ["データ", "調査", "市場", "統計", "分析", "リサーチ", "競合情報", "トレンド調査"],
}

ORDER = ["shin", "rex", "maya", "ken", "zero", "rin", "lex", "hana", "noa", "ami", "sage"]

SUMMARY_PROMPT = (
    "あなたはAI会社チームの議論を統合するシステムです。"
    "チームメンバーの各意見を整理し、以下の形式で統合レポートを作成してください：\n\n"
    "## 🎯 結論・推奨アクション\n（最も重要な結論と具体的な次のステップ）\n\n"
    "## 💡 チームの主要な知見\n（各部門から出た重要なポイントをまとめる）\n\n"
    "## ⚠️ 注意点・リスク\n（法務・財務・リスク観点での注意点）\n\n"
    "## 🚀 実行計画（優先順位順）\n（具体的なアクションリスト）\n\n"
    "簡潔で実行可能な内容にまとめ、必ず日本語で回答してください。"
)

# ─── ルーティング ────────────────────────────────────────────────────────────

def route_characters(question, mode="smart"):
    if mode == "all":
        return CHARACTERS, "全員モード: 全キャラクターが参加します"

    matched = {"shin", "sage"}
    lq = question.lower()
    for char_id, keywords in KEYWORD_MAP.items():
        if any(kw.lower() in lq for kw in keywords):
            matched.add(char_id)

    if len(matched) < 4:
        matched.update({"rex", "maya", "ken"})

    chars = [CHAR_BY_ID[cid] for cid in ORDER if cid in matched]
    reason = f"スマートルーティング: {'・'.join(c['name'] for c in chars)} が参加"
    return chars, reason

# ─── Claude CLI 呼び出し ──────────────────────────────────────────────────────

def call_claude_stream(system_prompt, user_message, context=""):
    system_section = f"あなたは以下の設定に従って応答してください：\n\n{system_prompt}"
    if context:
        user_section = f"【これまでの議論】\n{context}\n\n【オーナーの指示/質問】\n{user_message}"
    else:
        user_section = user_message

    full_prompt = f"{system_section}\n\n---\n\n{user_section}"

    proc = subprocess.Popen(
        ["claude", "-p", full_prompt],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    for chunk in proc.stdout:
        yield chunk
    proc.wait()

def build_context(responses):
    return "\n\n".join(
        f"【{r['emoji']} {r['name']}（{r['department']}）の意見】\n{r['content']}"
        for r in responses
    )

# ─── SSEイベント生成 ─────────────────────────────────────────────────────────

def generate_sse(question, mode):
    def sse(data):
        return f"data: {json.dumps(data, ensure_ascii=False)}\n\n"

    chars, reason = route_characters(question, mode)
    yield sse({"type": "routing", "reason": reason,
               "characters": [{"name": c["name"], "emoji": c["emoji"], "department": c["department"]} for c in chars]})

    responses = []
    context = ""

    for char in chars:
        yield sse({"type": "character_start", "id": char["id"], "name": char["name"],
                   "emoji": char["emoji"], "department": char["department"]})
        parts = []
        try:
            for chunk in call_claude_stream(char["systemPrompt"], question, context):
                parts.append(chunk)
                yield sse({"type": "chunk", "text": chunk})
            content = "".join(parts).strip()
            yield sse({"type": "character_end", "catchphrase": char["catchphrase"]})
            responses.append({"emoji": char["emoji"], "name": char["name"],
                               "department": char["department"], "content": content})
            context = build_context(responses)
        except Exception as e:
            yield sse({"type": "chunk", "text": f"[エラー: {e}]"})
            yield sse({"type": "character_end", "catchphrase": char["catchphrase"]})

        time.sleep(0.3)

    # 統合サマリー
    yield sse({"type": "summary_start"})
    summary_user = f"オーナーからの質問・指示:\n{question}\n\n{context}"
    try:
        for chunk in call_claude_stream(SUMMARY_PROMPT, summary_user):
            yield sse({"type": "summary_chunk", "text": chunk})
    except Exception as e:
        yield sse({"type": "summary_chunk", "text": f"統合レポートの生成に失敗しました: {e}"})
    yield sse({"type": "summary_end"})
    yield sse({"type": "done"})

# ─── Flask ルート ─────────────────────────────────────────────────────────────

HTML = r"""<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="theme-color" content="#0a0a0f">
  <title>AI会社チーム</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root { --bg:#0a0a0f; --bg2:#13131a; --bg3:#1a1a24; --border:#2a2a38; --accent:#00d4ff; --text:#e0e0e0; --dim:#888; --gold:#ffc107; --red:#ff4444; }
    body { background:var(--bg); color:var(--text); font-family:-apple-system,BlinkMacSystemFont,'Hiragino Sans','Yu Gothic',sans-serif; min-height:100dvh; display:flex; flex-direction:column; overflow:hidden; }
    header { background:var(--bg2); border-bottom:1px solid var(--border); padding:12px 16px; display:flex; align-items:center; justify-content:space-between; flex-shrink:0; }
    header h1 { font-size:1rem; color:var(--accent); font-weight:700; }
    header p { font-size:0.7rem; color:var(--dim); }
    .header-right { display:flex; gap:8px; }
    .toggle-btn { background:var(--bg3); border:1px solid var(--border); border-radius:20px; padding:5px 12px; color:var(--dim); font-size:0.72rem; cursor:pointer; white-space:nowrap; transition:all 0.2s; }
    .toggle-btn.on { border-color:var(--accent); color:var(--accent); background:#00d4ff18; }
    .toggle-btn.all { border-color:#a78bfa; color:#a78bfa; background:#a78bfa18; }
    #chat { flex:1; overflow-y:auto; padding:14px 12px; display:flex; flex-direction:column; gap:10px; -webkit-overflow-scrolling:touch; }
    .msg-user { align-self:flex-end; background:#1e3a6e; border-radius:18px 18px 4px 18px; padding:10px 15px; max-width:82%; font-size:0.9rem; line-height:1.5; word-break:break-word; }
    .info-pill { background:var(--bg2); border:1px solid var(--border); border-radius:8px; padding:7px 12px; font-size:0.75rem; color:var(--dim); }
    .info-pill.err { border-color:var(--red); color:var(--red); }
    .char-card { background:var(--bg2); border-radius:12px; border:1px solid var(--border); overflow:hidden; }
    .char-head { padding:8px 13px; display:flex; align-items:center; gap:7px; font-size:0.8rem; font-weight:700; }
    .char-dept { font-weight:400; color:var(--dim); font-size:0.72rem; margin-left:2px; }
    .char-body { padding:10px 13px; font-size:0.875rem; line-height:1.65; color:#d5d5d5; white-space:pre-wrap; word-break:break-word; }
    .char-foot { padding:5px 13px; font-size:0.7rem; color:var(--dim); font-style:italic; border-top:1px solid var(--border); }
    .summary-card { background:#120e00; border:1px solid #4a3800; border-radius:12px; overflow:hidden; }
    .summary-head { background:#1e1800; padding:9px 13px; color:var(--gold); font-size:0.83rem; font-weight:700; }
    .summary-body { padding:12px 13px; font-size:0.875rem; line-height:1.7; white-space:pre-wrap; word-break:break-word; color:#e5d5aa; }
    #inputWrap { background:var(--bg2); border-top:1px solid var(--border); padding:10px 12px; padding-bottom:max(10px,env(safe-area-inset-bottom,10px)); flex-shrink:0; }
    .input-row { display:flex; gap:8px; align-items:flex-end; }
    textarea { flex:1; background:var(--bg3); border:1px solid var(--border); border-radius:20px; padding:10px 15px; color:var(--text); font-size:0.95rem; resize:none; max-height:110px; outline:none; font-family:inherit; line-height:1.4; transition:border-color 0.2s; }
    textarea:focus { border-color:var(--accent); }
    textarea::placeholder { color:var(--dim); }
    .icon-btn { width:46px; height:46px; border-radius:50%; border:none; cursor:pointer; font-size:1.2rem; display:flex; align-items:center; justify-content:center; flex-shrink:0; transition:all 0.2s; }
    #voiceBtn { background:var(--accent); color:#000; }
    #voiceBtn.rec { background:var(--red); animation:pulse 1s infinite; }
    @keyframes pulse { 0%,100%{transform:scale(1)} 50%{transform:scale(1.1)} }
    #sendBtn { background:#003d80; color:#fff; }
    #sendBtn:disabled { background:var(--bg3); color:var(--dim); cursor:default; }
    #sendBtn:not(:disabled) { background:#0066cc; }
    .c-shin{color:#00d4ff} .bg-shin{background:#00d4ff18;border-color:#00d4ff44}
    .c-rex{color:#ffc107} .bg-rex{background:#ffc10718;border-color:#ffc10744}
    .c-maya{color:#e040fb} .bg-maya{background:#e040fb18;border-color:#e040fb44}
    .c-ken{color:#00e676} .bg-ken{background:#00e67618;border-color:#00e67644}
    .c-zero{color:#ffee58} .bg-zero{background:#ffee5818;border-color:#ffee5844}
    .c-rin{color:#448aff} .bg-rin{background:#448aff18;border-color:#448aff44}
    .c-lex{color:#e0e0e0} .bg-lex{background:#e0e0e018;border-color:#e0e0e044}
    .c-hana{color:#f48fb1} .bg-hana{background:#f48fb118;border-color:#f48fb144}
    .c-noa{color:#80deea} .bg-noa{background:#80deea18;border-color:#80deea44}
    .c-ami{color:#ff5252} .bg-ami{background:#ff525218;border-color:#ff525244}
    .c-sage{color:#82b1ff} .bg-sage{background:#82b1ff18;border-color:#82b1ff44}
  </style>
</head>
<body>
  <header>
    <div><h1>🏢 AI会社チーム</h1><p>Multi-Agent • Claude powered</p></div>
    <div class="header-right">
      <button class="toggle-btn" id="modeBtn" onclick="toggleMode()">🎯 スマート</button>
      <button class="toggle-btn" id="ttsBtn" onclick="toggleTTS()">🔇 音声</button>
    </div>
  </header>
  <div id="chat"><div class="info-pill">👋 マイクボタンで音声入力、またはテキストで質問してください。</div></div>
  <div id="inputWrap">
    <div class="input-row">
      <button class="icon-btn" id="voiceBtn" onclick="toggleVoice()" title="音声入力">🎤</button>
      <textarea id="textInput" placeholder="チームへの質問..." rows="1" onkeydown="onKey(event)" oninput="resize(this)"></textarea>
      <button class="icon-btn" id="sendBtn" onclick="send()" disabled>➤</button>
    </div>
  </div>
<script>
  let mode='smart',ttsOn=false,isRec=false,busy=false,recog=null;
  const chat=document.getElementById('chat'),input=document.getElementById('textInput'),sendBtn=document.getElementById('sendBtn');
  input.addEventListener('input',()=>{ sendBtn.disabled=!input.value.trim()||busy; });
  function resize(el){ el.style.height='auto'; el.style.height=Math.min(el.scrollHeight,110)+'px'; }
  function onKey(e){ if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();send();} }
  function toggleMode(){ mode=mode==='smart'?'all':'smart'; const b=document.getElementById('modeBtn'); if(mode==='all'){b.textContent='👥 全員';b.className='toggle-btn all';}else{b.textContent='🎯 スマート';b.className='toggle-btn';} }
  function toggleTTS(){ ttsOn=!ttsOn; const b=document.getElementById('ttsBtn'); b.textContent=ttsOn?'🔊 音声ON':'🔇 音声'; b.className='toggle-btn'+(ttsOn?' on':''); if(!ttsOn)speechSynthesis.cancel(); }
  function toggleVoice(){
    const SR=window.SpeechRecognition||window.webkitSpeechRecognition;
    if(!SR){alert('このブラウザは音声認識未対応です（Chromeを使用してください）');return;}
    if(isRec){recog.stop();return;}
    recog=new SR(); recog.lang='ja-JP'; recog.interimResults=true;
    recog.onstart=()=>{ isRec=true; const b=document.getElementById('voiceBtn'); b.className='icon-btn rec'; b.textContent='⏹'; };
    recog.onresult=(e)=>{ const t=Array.from(e.results).map(r=>r[0].transcript).join(''); input.value=t; resize(input); sendBtn.disabled=!t.trim()||busy; if(e.results[e.results.length-1].isFinal){recog.stop();setTimeout(send,400);} };
    recog.onend=()=>{ isRec=false; const b=document.getElementById('voiceBtn'); b.className='icon-btn'; b.textContent='🎤'; };
    recog.onerror=()=>{ isRec=false; };
    recog.start();
  }
  function speak(text){ if(!ttsOn||!text)return; speechSynthesis.cancel(); const u=new SpeechSynthesisUtterance(text.replace(/#+\s*/g,'').slice(0,500)); u.lang='ja-JP'; u.rate=1.1; speechSynthesis.speak(u); }
  function esc(t){ const d=document.createElement('div'); d.appendChild(document.createTextNode(t)); return d.innerHTML; }
  function append(el){ chat.appendChild(el); chat.scrollTop=chat.scrollHeight; return el; }
  function pill(text,err=false){ const d=document.createElement('div'); d.className='info-pill'+(err?' err':''); d.textContent=text; return append(d); }
  async function send(){
    const q=input.value.trim(); if(!q||busy)return;
    busy=true; sendBtn.disabled=true; input.value=''; input.style.height='auto';
    const ub=document.createElement('div'); ub.className='msg-user'; ub.textContent=q; append(ub);
    const loader=pill('⏳ チームを招集中…');
    try{
      const resp=await fetch('/api/ask',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({question:q,mode})});
      if(!resp.ok)throw new Error('HTTP '+resp.status);
      loader.remove();
      const reader=resp.body.getReader(),dec=new TextDecoder();
      let buf='',curCard=null,curBody=null,sumCard=null,sumBody=null;
      const onEvent=(data)=>{
        switch(data.type){
          case 'routing': pill('🎯 '+data.reason); break;
          case 'character_start':{
            const id=(data.id||data.name||'').toLowerCase();
            curCard=document.createElement('div'); curCard.className='char-card bg-'+id;
            const head=document.createElement('div'); head.className='char-head c-'+id;
            head.innerHTML=esc(data.emoji)+' '+esc(data.name)+'<span class="char-dept">'+esc(data.department)+'</span>';
            curBody=document.createElement('div'); curBody.className='char-body';
            curCard.appendChild(head); curCard.appendChild(curBody); append(curCard); break;}
          case 'chunk': if(curBody){curBody.textContent+=data.text;chat.scrollTop=chat.scrollHeight;}else if(sumBody){sumBody.textContent+=data.text;chat.scrollTop=chat.scrollHeight;} break;
          case 'character_end': if(curCard&&curBody){const f=document.createElement('div');f.className='char-foot';f.textContent='「'+data.catchphrase+'」';curCard.appendChild(f);speak(curBody.textContent);}curCard=null;curBody=null; break;
          case 'summary_start': sumCard=document.createElement('div');sumCard.className='summary-card';const sh=document.createElement('div');sh.className='summary-head';sh.textContent='📋 統合レポート Summary';sumBody=document.createElement('div');sumBody.className='summary-body';sumCard.appendChild(sh);sumCard.appendChild(sumBody);append(sumCard); break;
          case 'summary_chunk': if(sumBody){sumBody.textContent+=data.text;chat.scrollTop=chat.scrollHeight;} break;
          case 'summary_end': if(sumBody)speak(sumBody.textContent);sumCard=null;sumBody=null; break;
          case 'error': pill('⚠️ '+data.message,true); break;
        }
      };
      while(true){ const{done,value}=await reader.read(); if(done)break; buf+=dec.decode(value,{stream:true}); const lines=buf.split('\n'); buf=lines.pop()??''; for(const line of lines){if(!line.startsWith('data: '))continue;try{onEvent(JSON.parse(line.slice(6)));}catch{}}}
    }catch(err){ loader.remove(); pill('⚠️ 接続エラー: '+err.message,true); }
    busy=false; sendBtn.disabled=!input.value.trim();
  }
</script>
</body>
</html>"""


@app.route("/")
def index():
    return HTML, 200, {"Content-Type": "text/html; charset=utf-8"}


@app.route("/api/members")
def members():
    return Response(
        json.dumps([{"id": c["id"], "name": c["name"], "emoji": c["emoji"],
                     "department": c["department"], "catchphrase": c["catchphrase"]}
                    for c in CHARACTERS], ensure_ascii=False),
        mimetype="application/json"
    )


@app.route("/api/ask", methods=["POST"])
def ask():
    data = request.get_json(force=True, silent=True) or {}
    question = data.get("question", "").strip()
    mode = data.get("mode", "smart")

    if not question:
        return Response(json.dumps({"error": "質問を入力してください"}, ensure_ascii=False),
                        status=400, mimetype="application/json")

    return Response(
        generate_sse(question, mode),
        mimetype="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no",
                 "Access-Control-Allow-Origin": "*"},
    )


# ─── 起動 ────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\n🚀 AI会社チーム Webサーバー起動！")
    print("   ブラウザ: http://localhost:5000")
    print("   Ctrl+C で停止\n")
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)
