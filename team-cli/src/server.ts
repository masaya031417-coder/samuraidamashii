#!/usr/bin/env node
import * as dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import path from 'path';
import { routeToCharacters } from './team/router';
import { runTeamDiscussionSSE } from './team/discussion-sse';
import { CHARACTERS } from './characters';

const app = express();
const PORT = Number(process.env.PORT) || 3000;

app.use(express.json());
app.use(express.static(path.join(__dirname, '../../public')));

app.get('/api/members', (_req, res) => {
  res.json(
    CHARACTERS.map((c) => ({
      id: c.id,
      name: c.name,
      emoji: c.emoji,
      department: c.department,
      role: c.role,
      catchphrase: c.catchphrase,
    }))
  );
});

app.post('/api/ask', async (req, res) => {
  const { question, mode = 'smart' } = req.body as { question: string; mode?: string };

  if (!question || typeof question !== 'string') {
    res.status(400).json({ error: '質問を入力してください' });
    return;
  }

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.flushHeaders();

  const send = (data: object) => res.write(`data: ${JSON.stringify(data)}\n\n`);

  try {
    const { characters, reason } = routeToCharacters(question, mode as 'all' | 'smart');
    send({
      type: 'routing',
      reason,
      characters: characters.map((c) => ({ name: c.name, emoji: c.emoji, department: c.department })),
    });
    await runTeamDiscussionSSE(question, characters, send);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    send({ type: 'error', message: msg });
  }

  send({ type: 'done' });
  res.end();
});

const networkInterfaces = require('os').networkInterfaces();
const localIp = Object.values(networkInterfaces as Record<string, any[]>)
  .flat()
  .find((i: any) => i.family === 'IPv4' && !i.internal)?.address ?? 'YOUR_IP';

app.listen(PORT, '0.0.0.0', () => {
  console.log('\n🚀 AI会社チーム Webサーバー起動！');
  console.log(`   Local:   http://localhost:${PORT}`);
  console.log(`   スマホ:  http://${localIp}:${PORT}  （同じWiFi）`);
  console.log(`   外部公開: npx ngrok http ${PORT}`);
  console.log('\n   Ctrl+C で停止\n');
});
