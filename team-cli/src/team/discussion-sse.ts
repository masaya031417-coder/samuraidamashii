import { Character, CharacterResponse } from '../characters/types';
import { callClaude } from '../api/claude';

export type SseSendFn = (data: object) => void;

async function callCharacterSSE(
  character: Character,
  userMessage: string,
  conversationContext: string,
  send: SseSendFn
): Promise<CharacterResponse> {
  send({
    type: 'character_start',
    id: character.id,
    name: character.name,
    emoji: character.emoji,
    department: character.department,
  });

  const onChunk = (chunk: string) => send({ type: 'chunk', text: chunk });

  try {
    const content = await callClaude(character, userMessage, conversationContext, onChunk);
    send({ type: 'character_end', catchphrase: character.catchphrase });
    return { character, content };
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    const fallback = `[${character.name}のAPIに接続できませんでした: ${errorMsg}]`;
    send({ type: 'chunk', text: fallback });
    send({ type: 'character_end', catchphrase: character.catchphrase });
    return { character, content: fallback, error: errorMsg };
  }
}

function buildContext(responses: CharacterResponse[]): string {
  return responses
    .filter((r) => !r.error)
    .map((r) => `【${r.character.emoji} ${r.character.name}（${r.character.department}）の意見】\n${r.content}`)
    .join('\n\n');
}

const SUMMARY_CHARACTER: Character = {
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

export async function runTeamDiscussionSSE(
  userMessage: string,
  characters: Character[],
  send: SseSendFn
): Promise<void> {
  const responses: CharacterResponse[] = [];
  let conversationContext = '';

  for (const character of characters) {
    const response = await callCharacterSSE(character, userMessage, conversationContext, send);
    responses.push(response);
    if (!response.error) {
      conversationContext = buildContext(responses);
    }
    await new Promise((resolve) => setTimeout(resolve, 300));
  }

  send({ type: 'summary_start' });

  const context = buildContext(responses);
  const prompt = `オーナーからの質問・指示:\n${userMessage}\n\n${context}`;
  const onChunk = (chunk: string) => send({ type: 'summary_chunk', text: chunk });

  try {
    await callClaude(SUMMARY_CHARACTER, prompt, '', onChunk);
  } catch {
    send({ type: 'summary_chunk', text: '統合レポートの生成に失敗しました。' });
  }

  send({ type: 'summary_end' });
}
