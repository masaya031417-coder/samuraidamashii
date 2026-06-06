#!/usr/bin/env node

import * as dotenv from 'dotenv';
import * as readline from 'readline';
import { Command } from 'commander';
import { runTeamDiscussion } from './team/discussion';
import { routeToCharacters } from './team/router';
import {
  printBanner,
  printTeamMembers,
  printUserPrompt,
  printError,
  printInfo,
  printDivider,
} from './display/terminal';

dotenv.config();

const program = new Command();

program
  .name('team')
  .description('AI会社チーム Multi-Agent CLI System')
  .version('1.0.0');

program
  .command('chat')
  .description('チームとの対話モードを開始')
  .option('-m, --mode <mode>', 'ルーティングモード: all | smart', 'smart')
  .action(async (options) => {
    printBanner();
    checkApiKeys();

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: false,
    });

    const mode = options.mode as 'all' | 'smart';
    printInfo(`ルーティングモード: ${mode === 'all' ? '全員参加' : 'スマート（関連キャラクターを自動選択）'}`);
    printInfo('質問を入力してください。"exit"で終了、"members"でメンバー一覧、"mode all/smart"でモード切替');

    const askQuestion = (): void => {
      printUserPrompt();

      rl.once('line', async (input) => {
        const trimmed = input.trim();

        if (!trimmed) {
          askQuestion();
          return;
        }

        if (trimmed === 'exit' || trimmed === 'quit') {
          console.log('\n👋 チームを解散します。またいつでもどうぞ！\n');
          rl.close();
          process.exit(0);
        }

        if (trimmed === 'members') {
          printTeamMembers();
          askQuestion();
          return;
        }

        if (trimmed.startsWith('mode ')) {
          const newMode = trimmed.slice(5).trim() as 'all' | 'smart';
          if (newMode === 'all' || newMode === 'smart') {
            options.mode = newMode;
            printInfo(`モードを変更: ${newMode === 'all' ? '全員参加' : 'スマート'}`);
          } else {
            printError('モードは "all" または "smart" を指定してください');
          }
          askQuestion();
          return;
        }

        try {
          const currentMode = options.mode as 'all' | 'smart';
          const { characters, reason } = routeToCharacters(trimmed, currentMode);
          printInfo(reason);

          await runTeamDiscussion(trimmed, characters);
          printDivider();
        } catch (err) {
          const msg = err instanceof Error ? err.message : String(err);
          printError(`議論中にエラーが発生しました: ${msg}`);
        }

        askQuestion();
      });
    };

    askQuestion();
  });

program
  .command('ask <question>')
  .description('一回だけ質問してチームの回答を得る')
  .option('-m, --mode <mode>', 'ルーティングモード: all | smart', 'smart')
  .option('-c, --characters <ids>', 'キャラクターIDをカンマ区切りで指定 (例: shin,ken,rin)')
  .action(async (question, options) => {
    printBanner();
    checkApiKeys();

    let characters;

    if (options.characters) {
      const { CHARACTERS } = await import('./characters');
      const ids = options.characters.split(',').map((s: string) => s.trim());
      characters = CHARACTERS.filter((c) => ids.includes(c.id));
      if (characters.length === 0) {
        printError(`指定されたキャラクターが見つかりません: ${options.characters}`);
        process.exit(1);
      }
      printInfo(`指定キャラクター: ${characters.map((c) => c.name).join('・')}`);
    } else {
      const routing = routeToCharacters(question, options.mode as 'all' | 'smart');
      characters = routing.characters;
      printInfo(routing.reason);
    }

    try {
      await runTeamDiscussion(question, characters);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      printError(`エラーが発生しました: ${msg}`);
      process.exit(1);
    }

    process.exit(0);
  });

program
  .command('members')
  .description('チームメンバー一覧を表示')
  .action(() => {
    printBanner();
    printTeamMembers();
  });

function checkApiKeys(): void {
  const missing: string[] = [];

  if (!process.env.ANTHROPIC_API_KEY) missing.push('ANTHROPIC_API_KEY (Claude用)');
  if (!process.env.OPENAI_API_KEY) missing.push('OPENAI_API_KEY (REX・ZERO・NOA用)');
  if (!process.env.GEMINI_API_KEY) missing.push('GEMINI_API_KEY (RIN・SAGE用)');

  if (missing.length > 0) {
    printInfo('以下のAPIキーが未設定です（該当キャラクターはスキップされます）:');
    for (const key of missing) {
      printInfo(`  ⚠️  ${key}`);
    }
    printInfo('.env ファイルに設定してください (.env.example を参照)');
    console.log();
  }
}

// デフォルトでchatコマンドを実行
if (process.argv.length === 2) {
  process.argv.push('chat');
}

program.parse(process.argv);
