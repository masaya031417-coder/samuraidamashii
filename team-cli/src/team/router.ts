import { Character } from '../characters/types';
import { CHARACTERS } from '../characters';

export interface RoutingDecision {
  characters: Character[];
  reason: string;
}

const KEYWORD_MAP: Record<string, string[]> = {
  shin: ['戦略', '計画', '長期', '方針', '意思決定', 'ビジョン', '競合', '市場参入', '経営'],
  rex: ['速度', '最速', '実行', 'スピード', 'ASAP', '今すぐ', '緊急'],
  maya: ['マーケ', '営業', 'SNS', 'コピー', '広告', '集客', 'バズ', 'ブランド', 'プロモ', '訴求'],
  ken: ['コード', '実装', 'プログラム', 'システム', '開発', 'バグ', 'エラー', 'API', 'データベース', '技術'],
  zero: ['プロトタイプ', '実験', 'PoC', 'テスト', '新技術', 'ハック'],
  rin: ['収益', '利益', 'コスト', 'ROI', '予算', '財務', '資金', '投資', '売上', '経費', 'お金'],
  lex: ['法律', 'リスク', '契約', '規約', '著作権', '個人情報', 'コンプライアンス', '訴訟', '規制'],
  hana: ['採用', '人材', '組織', '文化', 'チーム', '評価', '面接', '雇用', 'HR', '人事'],
  noa: ['新規事業', 'アイデア', 'イノベーション', '斬新', '新しい', '未来', 'トレンド', '破壊的'],
  ami: ['顧客', 'お客様', 'クレーム', 'サポート', 'FAQ', 'UX', 'ユーザー体験', '返金', '対応'],
  sage: ['データ', '調査', '市場', '統計', '分析', 'リサーチ', '競合情報', 'トレンド調査'],
};

export function routeToCharacters(userMessage: string, mode: 'all' | 'smart' = 'smart'): RoutingDecision {
  if (mode === 'all') {
    return {
      characters: CHARACTERS,
      reason: '全員モード: 全キャラクターが参加します',
    };
  }

  const matched = new Set<string>();
  const lowerMessage = userMessage.toLowerCase();

  for (const [charId, keywords] of Object.entries(KEYWORD_MAP)) {
    for (const kw of keywords) {
      if (lowerMessage.includes(kw.toLowerCase())) {
        matched.add(charId);
        break;
      }
    }
  }

  // 常にSHINとSAGEは参加（戦略と情報収集は常に必要）
  matched.add('shin');
  matched.add('sage');

  // マッチが少なければコアメンバーを追加
  if (matched.size < 4) {
    matched.add('rex');
    matched.add('maya');
    matched.add('ken');
  }

  const orderedIds = ['shin', 'rex', 'maya', 'ken', 'zero', 'rin', 'lex', 'hana', 'noa', 'ami', 'sage'];
  const characters = orderedIds
    .filter((id) => matched.has(id))
    .map((id) => CHARACTERS.find((c) => c.id === id)!)
    .filter(Boolean);

  return {
    characters,
    reason: `スマートルーティング: ${characters.map((c) => c.name).join('・')} が参加`,
  };
}
