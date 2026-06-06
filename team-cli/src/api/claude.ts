import Anthropic from '@anthropic-ai/sdk';
import { Character, Message } from '../characters/types';

let client: Anthropic | null = null;

function getClient(): Anthropic {
  if (!client) {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      throw new Error('ANTHROPIC_API_KEY が設定されていません');
    }
    client = new Anthropic({ apiKey });
  }
  return client;
}

export async function callClaude(
  character: Character,
  userMessage: string,
  conversationContext: string,
  onChunk?: (chunk: string) => void
): Promise<string> {
  const anthropic = getClient();
  const model = process.env.CLAUDE_MODEL || 'claude-sonnet-4-6';

  const fullMessage = conversationContext
    ? `【これまでの議論】\n${conversationContext}\n\n【オーナーの指示/質問】\n${userMessage}`
    : userMessage;

  let fullResponse = '';

  const stream = anthropic.messages.stream({
    model,
    max_tokens: 1024,
    system: character.systemPrompt,
    messages: [{ role: 'user', content: fullMessage }],
  });

  for await (const chunk of stream) {
    if (
      chunk.type === 'content_block_delta' &&
      chunk.delta.type === 'text_delta'
    ) {
      const text = chunk.delta.text;
      fullResponse += text;
      if (onChunk) onChunk(text);
    }
  }

  return fullResponse;
}
