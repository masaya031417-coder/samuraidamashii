import { Character, CharacterResponse } from '../characters/types';

const RESET = '\x1b[0m';
const BOLD = '\x1b[1m';
const DIM = '\x1b[2m';
const BG_DARK = '\x1b[40m';

export function clearLine(): void {
  process.stdout.write('\r\x1b[K');
}

export function printBanner(): void {
  console.log('\n' + BOLD + '\x1b[36m');
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║          🏢  AI会社チーム  Multi-Agent CLI System            ║');
  console.log('║              Powered by Claude × OpenAI × Gemini             ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');
  console.log(RESET);
  console.log(DIM + '  チームメンバー: SHIN・REX・MAYA・KEN・ZERO・RIN・LEX・HANA・NOA・AMI・SAGE' + RESET);
  console.log(DIM + '  コマンド: "exit" または "quit" で終了 | "members" でメンバー一覧' + RESET);
  console.log();
}

export function printTeamMembers(): void {
  const members = [
    { emoji: '🧠', name: 'SHIN', dept: '経営・戦略', api: 'Claude', role: '全体戦略・長期計画' },
    { emoji: '⚡', name: 'REX', dept: '戦略補佐', api: 'Claude', role: 'スピード反論・別視点' },
    { emoji: '🔥', name: 'MAYA', dept: 'マーケ・営業', api: 'Claude', role: 'SNS戦略・コピー量産' },
    { emoji: '💻', name: 'KEN', dept: 'エンジニア', api: 'Claude', role: 'コード生成・システム構築' },
    { emoji: '🚀', name: 'ZERO', dept: '開発補佐', api: 'Claude', role: 'プロトタイプ・新技術検証' },
    { emoji: '📊', name: 'RIN', dept: '財務・数字', api: 'Claude', role: '収益計算・ROI分析' },
    { emoji: '⚖️', name: 'LEX', dept: '法務・リスク', api: 'Claude', role: '契約リスク・法的チェック' },
    { emoji: '👥', name: 'HANA', dept: '人事・採用', api: 'Claude', role: '採用基準・組織文化' },
    { emoji: '💡', name: 'NOA', dept: '企画・イノベーション', api: 'Claude', role: '新規事業・破壊的提案' },
    { emoji: '🎧', name: 'AMI', dept: 'カスタマーサポート', api: 'Claude', role: '顧客対応・FAQ作成' },
    { emoji: '🔍', name: 'SAGE', dept: 'データ・リサーチ', api: 'Claude', role: '市場調査・競合分析' },
  ];

  console.log('\n' + BOLD + '━━━ チームメンバー一覧 ━━━' + RESET + '\n');
  for (const m of members) {
    const apiColor = m.api === 'Claude' ? '\x1b[36m' : m.api === 'OpenAI' ? '\x1b[32m' : '\x1b[34m';
    console.log(
      `  ${m.emoji} ${BOLD}${m.name.padEnd(6)}${RESET} ` +
        `${DIM}[${m.dept}]${RESET}  ` +
        `${apiColor}(${m.api})${RESET}  ` +
        `${m.role}`
    );
  }
  console.log();
}

export function printCharacterHeader(character: Character): void {
  const providerLabel =
    character.provider === 'claude'
      ? '\x1b[36m[Claude]\x1b[0m'
      : character.provider === 'openai'
        ? '\x1b[32m[OpenAI]\x1b[0m'
        : '\x1b[34m[Gemini]\x1b[0m';

  console.log(
    '\n' +
      character.color +
      BOLD +
      `┌─── ${character.emoji} ${character.name} ` +
      RESET +
      DIM +
      `(${character.department}) ` +
      RESET +
      providerLabel
  );
  console.log(character.color + '│' + RESET);
}

export function printCharacterChunk(character: Character, text: string): void {
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i++) {
    if (i === 0) {
      process.stdout.write(character.color + '│  ' + RESET + lines[i]);
    } else {
      process.stdout.write('\n' + character.color + '│  ' + RESET + lines[i]);
    }
  }
}

export function printCharacterFooter(character: Character): void {
  console.log(
    '\n' + character.color + '└' + DIM + `─── 「${character.catchphrase}」` + RESET
  );
}

export function printSummaryHeader(): void {
  console.log('\n' + BOLD + '\x1b[33m');
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║                  📋  統合レポート  Summary                   ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');
  console.log(RESET);
}

export function printSummaryChunk(text: string): void {
  process.stdout.write('\x1b[33m' + text + RESET);
}

export function printSummaryFooter(): void {
  console.log('\n\n' + BOLD + '\x1b[33m' + '━'.repeat(64) + RESET + '\n');
}

export function printDivider(): void {
  console.log(DIM + '\n  ' + '·'.repeat(60) + '\n' + RESET);
}

export function printUserPrompt(): void {
  process.stdout.write('\n' + BOLD + '👑 あなた > ' + RESET);
}

export function printError(message: string): void {
  console.error('\n\x1b[31m⚠️  ' + message + RESET + '\n');
}

export function printInfo(message: string): void {
  console.log(DIM + '  ℹ️  ' + message + RESET);
}

export function printDiscussionStart(topic: string, count: number): void {
  console.log('\n' + BOLD + `\n🏢 チーム議論を開始します（${count}名が参加）` + RESET);
  console.log(DIM + `  テーマ: "${topic.slice(0, 60)}${topic.length > 60 ? '...' : ''}"` + RESET);
  console.log(DIM + '  ' + '━'.repeat(60) + RESET);
}
