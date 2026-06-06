import { Character, CharacterResponse, TeamDiscussionResult } from '../characters/types';
import { callClaude } from '../api/claude';
import { callOpenAI } from '../api/openai';
import { callGemini } from '../api/gemini';
import {
  printCharacterHeader,
  printCharacterChunk,
  printCharacterFooter,
  printSummaryHeader,
  printSummaryChunk,
  printSummaryFooter,
  printDiscussionStart,
  printError,
  printInfo,
} from '../display/terminal';

async function callCharacter(
  character: Character,
  userMessage: string,
  conversationContext: string
): Promise<CharacterResponse> {
  const onChunk = (chunk: string) => printCharacterChunk(character, chunk);

  try {
    let content: string;

    switch (character.provider) {
      case 'claude':
        content = await callClaude(character, userMessage, conversationContext, onChunk);
        break;
      case 'openai':
        content = await callOpenAI(character, userMessage, conversationContext, onChunk);
        break;
      case 'gemini':
        content = await callGemini(character, userMessage, conversationContext, onChunk);
        break;
    }

    return { character, content };
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    const fallbackMsg = `[${character.name}のAPIに接続できませんでした: ${errorMsg}]`;
    process.stdout.write(fallbackMsg);
    return { character, content: fallbackMsg, error: errorMsg };
  }
}

function buildContext(responses: CharacterResponse[]): string {
  return responses
    .filter((r) => !r.error)
    .map((r) => `【${r.character.emoji} ${r.character.name}（${r.character.department}）の意見】\n${r.content}`)
    .join('\n\n');
}

async function generateSummary(
  userMessage: string,
  responses: CharacterResponse[]
): Promise<string> {
  const summaryCharacter: Character = {
    id: 'summary',
    name: 'SYSTEM',
    emoji: '📋',
    department: 'システム',
    personality: '統合・総括',
    role: '議論の統合レポート生成',
    catchphrase: '統合完了',
    systemPrompt: `あなたはAI会社チームの議論を統合するシステムです。
チームメンバーの各意見を整理し、以下の形式で統合レポートを作成してください：

## 🎯 結論・推奨アクション
（最も重要な結論と具体的な次のステップ）

## 💡 チームの主要な知見
（各部門から出た重要なポイントをまとめる）

## ⚠️ 注意点・リスク
（法務・財務・リスク観点での注意点）

## 🚀 実行計画（優先順位順）
（具体的なアクションリスト）

簡潔で実行可能な内容にまとめ、必ず日本語で回答してください。`,
    provider: 'claude',
    color: '\x1b[33m',
  };

  const context = buildContext(responses);
  const prompt = `オーナーからの質問・指示:\n${userMessage}\n\n${context}`;

  const onChunk = (chunk: string) => printSummaryChunk(chunk);

  try {
    return await callClaude(summaryCharacter, prompt, '', onChunk);
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    const fallback = '統合レポートの生成に失敗しました。各キャラクターの発言を参照してください。';
    process.stdout.write(fallback);
    return fallback;
  }
}

export async function runTeamDiscussion(
  userMessage: string,
  characters: Character[]
): Promise<TeamDiscussionResult> {
  printDiscussionStart(userMessage, characters.length);

  const responses: CharacterResponse[] = [];
  let conversationContext = '';

  for (const character of characters) {
    printCharacterHeader(character);

    const response = await callCharacter(character, userMessage, conversationContext);
    responses.push(response);

    printCharacterFooter(character);

    // 次のキャラクターのために会話コンテキストを更新
    if (!response.error) {
      conversationContext = buildContext(responses);
    }

    // レート制限対策の短いディレイ
    await new Promise((resolve) => setTimeout(resolve, 300));
  }

  printSummaryHeader();
  const summary = await generateSummary(userMessage, responses);
  printSummaryFooter();

  return {
    topic: userMessage,
    responses,
    summary,
  };
}
