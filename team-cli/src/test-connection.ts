#!/usr/bin/env ts-node
/**
 * APIキーの接続テストスクリプト
 * 使用方法: npx ts-node src/test-connection.ts
 */

import * as dotenv from 'dotenv';
dotenv.config();

const RESET = '\x1b[0m';
const GREEN = '\x1b[32m';
const RED = '\x1b[31m';
const YELLOW = '\x1b[33m';
const BOLD = '\x1b[1m';

async function testClaude(): Promise<boolean> {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    console.log(`  ${YELLOW}⚠️  ANTHROPIC_API_KEY 未設定 → Claude系キャラ (SHIN/MAYA/KEN/LEX/HANA/AMI) はスキップ${RESET}`);
    return false;
  }
  try {
    const Anthropic = (await import('@anthropic-ai/sdk')).default;
    const client = new Anthropic({ apiKey });
    const res = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 50,
      messages: [{ role: 'user', content: 'テスト' }],
    });
    console.log(`  ${GREEN}✅ Claude API 接続成功${RESET}`);
    return true;
  } catch (e) {
    console.log(`  ${RED}❌ Claude API 接続失敗: ${e instanceof Error ? e.message : e}${RESET}`);
    return false;
  }
}

async function testOpenAI(): Promise<boolean> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    console.log(`  ${YELLOW}⚠️  OPENAI_API_KEY 未設定 → OpenAI系キャラ (REX/ZERO/NOA) はスキップ${RESET}`);
    return false;
  }
  try {
    const OpenAI = (await import('openai')).default;
    const client = new OpenAI({ apiKey });
    await client.models.list();
    console.log(`  ${GREEN}✅ OpenAI API 接続成功${RESET}`);
    return true;
  } catch (e) {
    console.log(`  ${RED}❌ OpenAI API 接続失敗: ${e instanceof Error ? e.message : e}${RESET}`);
    return false;
  }
}

async function testGemini(): Promise<boolean> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.log(`  ${YELLOW}⚠️  GEMINI_API_KEY 未設定 → Gemini系キャラ (RIN/SAGE) はスキップ${RESET}`);
    return false;
  }
  try {
    const { GoogleGenerativeAI } = await import('@google/generative-ai');
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    await model.generateContent('テスト');
    console.log(`  ${GREEN}✅ Gemini API 接続成功${RESET}`);
    return true;
  } catch (e) {
    console.log(`  ${RED}❌ Gemini API 接続失敗: ${e instanceof Error ? e.message : e}${RESET}`);
    return false;
  }
}

async function main(): Promise<void> {
  console.log(`\n${BOLD}🔧 API接続テスト${RESET}\n`);
  const [claude, openai, gemini] = await Promise.all([testClaude(), testOpenAI(), testGemini()]);
  const count = [claude, openai, gemini].filter(Boolean).length;
  console.log(`\n${BOLD}結果: ${count}/3 APIが利用可能${RESET}`);
  if (count === 0) {
    console.log(`${RED}.env ファイルにAPIキーを設定してから再実行してください${RESET}`);
    console.log(`cp .env.example .env  # .envファイルを作成してAPIキーを記入\n`);
  }
}

main();
