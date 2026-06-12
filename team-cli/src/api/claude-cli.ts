import { spawn } from 'child_process';
import { Character } from '../characters/types';

export async function callClaude(
  character: Character,
  userMessage: string,
  conversationContext: string,
  onChunk?: (chunk: string) => void
): Promise<string> {
  const fullPrompt = [
    `あなたは以下の設定に従って応答してください：\n\n${character.systemPrompt}`,
    '---',
    conversationContext ? `【これまでの議論】\n${conversationContext}\n\n【オーナーの指示/質問】\n${userMessage}` : userMessage,
  ].join('\n\n');

  return new Promise((resolve, reject) => {
    const proc = spawn('claude', ['-p', fullPrompt], { env: process.env });

    let result = '';

    proc.stdout.on('data', (data: Buffer) => {
      const text = data.toString();
      result += text;
      if (onChunk) onChunk(text);
    });

    proc.on('close', (code) => {
      if (code === 0) resolve(result.trim());
      else reject(new Error(`claude CLI がコード ${code} で終了しました`));
    });

    proc.on('error', () => {
      reject(new Error('claude コマンドが見つかりません。Claude Code がインストール済みか確認してください。'));
    });
  });
}
