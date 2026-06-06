export type ApiProvider = 'claude' | 'openai' | 'gemini';

export interface Character {
  id: string;
  name: string;
  emoji: string;
  department: string;
  personality: string;
  role: string;
  catchphrase: string;
  systemPrompt: string;
  provider: ApiProvider;
  color: string;
}

export interface Message {
  role: 'user' | 'assistant';
  content: string;
}

export interface CharacterResponse {
  character: Character;
  content: string;
  error?: string;
}

export interface TeamDiscussionResult {
  topic: string;
  responses: CharacterResponse[];
  summary: string;
}
