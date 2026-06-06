import OpenAI from 'openai';
import { Character } from '../characters/types';

let client: OpenAI | null = null;

function getClient(): OpenAI {
  if (!client) {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      throw new Error('OPENAI_API_KEY が設定されていません');
    }
    client = new OpenAI({ apiKey });
  }
  return client;
}

export async function callOpenAI(
  character: Character,
  userMessage: string,
  conversationContext: string,
  onChunk?: (chunk: string) => void
): Promise<string> {
  const openai = getClient();
  const model = process.env.OPENAI_MODEL || 'gpt-4o';

  const fullMessage = conversationContext
    ? `【これまでの議論】\n${conversationContext}\n\n【オーナーの指示/質問】\n${userMessage}`
    : userMessage;

  const stream = await openai.chat.completions.create({
    model,
    max_tokens: 1024,
    stream: true,
    messages: [
      { role: 'system', content: character.systemPrompt },
      { role: 'user', content: fullMessage },
    ],
  });

  let fullResponse = '';

  for await (const chunk of stream) {
    const text = chunk.choices[0]?.delta?.content ?? '';
    if (text) {
      fullResponse += text;
      if (onChunk) onChunk(text);
    }
  }

  return fullResponse;
}
