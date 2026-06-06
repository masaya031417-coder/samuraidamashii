import { GoogleGenerativeAI } from '@google/generative-ai';
import { Character } from '../characters/types';

let genAI: GoogleGenerativeAI | null = null;

function getClient(): GoogleGenerativeAI {
  if (!genAI) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY が設定されていません');
    }
    genAI = new GoogleGenerativeAI(apiKey);
  }
  return genAI;
}

export async function callGemini(
  character: Character,
  userMessage: string,
  conversationContext: string,
  onChunk?: (chunk: string) => void
): Promise<string> {
  const ai = getClient();
  const modelName = process.env.GEMINI_MODEL || 'gemini-1.5-flash';
  const model = ai.getGenerativeModel({
    model: modelName,
    systemInstruction: character.systemPrompt,
  });

  const fullMessage = conversationContext
    ? `【これまでの議論】\n${conversationContext}\n\n【オーナーの指示/質問】\n${userMessage}`
    : userMessage;

  const result = await model.generateContentStream(fullMessage);

  let fullResponse = '';

  for await (const chunk of result.stream) {
    const text = chunk.text();
    if (text) {
      fullResponse += text;
      if (onChunk) onChunk(text);
    }
  }

  return fullResponse;
}
