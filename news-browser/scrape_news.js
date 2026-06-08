/**
 * scrape_news.js
 * 金融・経済・政治ニュース スクレイパー (Playwright使用 / APIキー不要)
 *
 * 対象サイト:
 *   1. Reuters         - https://www.reuters.com
 *   2. Yahoo Finance   - https://finance.yahoo.com
 *   3. MarketWatch     - https://www.marketwatch.com
 *   4. CNBC Economy    - https://www.cnbc.com/economy
 *   5. BBC Business    - https://www.bbc.com/news/business
 *
 * 使用方法:
 *   node scrape_news.js          # ライブスクレイピング
 *   node scrape_news.js --demo   # デモモード（ネットワーク不要）
 */

const { chromium } = require('playwright');

const SITES = [
  {
    name: 'Reuters',
    url: 'https://www.reuters.com',
    category: '総合・国際',
    selectors: {
      articles: '[data-testid="Heading"] a, .article-heading a, h3 a',
      summary: '[data-testid="Body"] p, .article-body__content p',
    },
    waitFor: '[data-testid="Heading"], .article-heading, h3 a',
    maxArticles: 5,
  },
  {
    name: 'Yahoo Finance',
    url: 'https://finance.yahoo.com',
    category: '金融・株式',
    selectors: {
      articles: 'h3 a[href*="/news/"], .stream-item h3 a, [data-test-id="mega-stream-item"] h3 a',
      summary: 'p[class*="clamp"]',
    },
    waitFor: 'h3 a[href*="/news/"], .stream-item',
    maxArticles: 5,
  },
  {
    name: 'MarketWatch',
    url: 'https://www.marketwatch.com',
    category: '市場・経済',
    selectors: {
      articles: '.article__headline a, h3.article__headline a, .element--article h3 a',
      summary: '.article__summary, p.article__summary',
    },
    waitFor: '.article__headline, .element--article',
    maxArticles: 5,
  },
  {
    name: 'CNBC Economy',
    url: 'https://www.cnbc.com/economy/',
    category: '経済・政策',
    selectors: {
      articles: '.Card-title a, .card-title a, .LatestNews-headline a, h2 a',
      summary: '.Card-description, .card-description',
    },
    waitFor: '.Card-title, .card-title, h2 a',
    maxArticles: 5,
  },
  {
    name: 'BBC Business',
    url: 'https://www.bbc.com/news/business',
    category: '経済・国際政治',
    selectors: {
      articles: '[data-testid="anchor-inner-wrapper"] h3, .gs-c-promo-heading a, h3[class*="PromoHeadline"] a',
      summary: '[data-testid="anchor-inner-wrapper"] p, .gs-c-promo-summary',
    },
    waitFor: '[data-testid="anchor-inner-wrapper"], .gs-c-promo-heading',
    maxArticles: 5,
  },
];

async function scrapeSite(browser, site) {
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    extraHTTPHeaders: { 'Accept-Language': 'ja,en-US;q=0.9,en;q=0.8' },
  });
  const page = await context.newPage();
  const articles = [];

  try {
    await page.goto(site.url, { waitUntil: 'domcontentloaded', timeout: 20000 });
    try { await page.waitForSelector(site.waitFor, { timeout: 8000 }); } catch {}

    const elements = await page.$$(site.selectors.articles);
    for (let i = 0; i < Math.min(elements.length, site.maxArticles); i++) {
      const el = elements[i];
      const headline = await el.textContent().then((t) => t?.trim()).catch(() => '');
      if (!headline || headline.length < 5) continue;

      let href = await el.getAttribute('href').catch(() => '');
      if (href && !href.startsWith('http')) {
        href = `${new URL(site.url).origin}${href}`;
      }

      let summary = '';
      try {
        const parent = await el.evaluateHandle((node) => {
          let p = node;
          for (let i = 0; i < 4; i++) {
            p = p.parentElement;
            if (!p) break;
            const s = p.querySelector('p, [class*="summary"], [class*="description"]');
            if (s) return s;
          }
          return null;
        });
        if (parent) {
          summary = await parent.textContent().then((t) => t?.trim().slice(0, 150)).catch(() => '');
          await parent.dispose();
        }
      } catch {}

      articles.push({ headline, summary: summary || '（概要なし）', url: href });
    }
  } catch (err) {
    console.error(`  [ERROR] ${site.name}: ${err.message}`);
  } finally {
    await context.close();
  }
  return articles;
}

async function runLive() {
  console.log('='.repeat(60));
  console.log('  金融・経済・政治ニュース スクレイパー (Playwright)');
  console.log(`  実行日時: ${new Date().toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' })} JST`);
  console.log('='.repeat(60));

  const browser = await chromium.launch({ headless: true });
  const allResults = [];

  for (const site of SITES) {
    console.log(`\n【${site.name}】 (${site.category})`);
    console.log(`  URL: ${site.url}`);
    console.log('  取得中...');
    const articles = await scrapeSite(browser, site);
    allResults.push({ site, articles });
    if (articles.length === 0) { console.log('  → 記事を取得できませんでした'); continue; }
    articles.forEach((a, i) => {
      console.log(`\n  ${i + 1}. ${a.headline}`);
      if (a.summary && a.summary !== '（概要なし）') console.log(`     概要: ${a.summary}`);
      if (a.url) console.log(`     URL: ${a.url}`);
    });
  }

  await browser.close();
  console.log('\n' + '='.repeat(60));
  console.log('  [LLM INPUT] 全取得記事（JSON形式）');
  console.log('='.repeat(60));
  console.log(JSON.stringify(allResults, null, 2));
  return allResults;
}

function runDemo() {
  const DEMO_DATA = [
    {
      site: { name: 'Reuters', category: '総合・国際' },
      articles: [
        { headline: 'Fed holds rates steady as inflation edges toward 2% target, signals caution on cuts', summary: 'The Federal Reserve kept interest rates unchanged Wednesday, as policymakers await more data before easing monetary policy amid persistent service-sector inflation.', url: 'https://www.reuters.com/markets/rates-bonds/fed-holds-rates-2026/' },
        { headline: 'China economy grows 4.8% in Q1 2026, missing 5% government target', summary: "China's economy expanded at a slower-than-expected pace in the first quarter, weighed down by weak consumer demand and ongoing property sector stress.", url: 'https://www.reuters.com/world/china/china-gdp-q1-2026/' },
        { headline: 'EU imposes new tariffs on US electric vehicles in retaliatory move', summary: 'The European Union announced sweeping tariffs on American electric vehicles following escalating trade tensions, raising fears of a full-scale trade war.', url: 'https://www.reuters.com/business/autos/eu-tariffs-us-ev-2026/' },
        { headline: 'Oil prices slip to $72 as OPEC+ signals production increase for Q2', summary: 'Crude futures fell sharply after OPEC+ members agreed to gradually unwind output cuts starting in April, adding supply to a market already facing demand uncertainty.', url: 'https://www.reuters.com/markets/commodities/oil-opec-q2-2026/' },
        { headline: 'Japan yen strengthens to 142 per dollar on BOJ rate hike expectations', summary: 'The yen rose to its strongest level in months as investors bet the Bank of Japan will raise its policy rate again amid persistently elevated wage growth.', url: 'https://www.reuters.com/markets/currencies/yen-boj-2026/' },
      ],
    },
    {
      site: { name: 'Yahoo Finance', category: '金融・株式' },
      articles: [
        { headline: 'S&P 500 falls 1.2% as tech selloff deepens on valuation concerns', summary: 'Wall Street suffered its worst session in three weeks as investors rotated out of high-multiple technology stocks following cautious guidance from major chip makers.', url: 'https://finance.yahoo.com/news/sp500-tech-selloff-2026/' },
        { headline: 'Nvidia surpasses $4 trillion market cap milestone on AI data center boom', summary: 'Nvidia briefly crossed the $4 trillion valuation threshold after reporting blockbuster quarterly revenue driven by insatiable demand for its AI accelerator chips.', url: 'https://finance.yahoo.com/news/nvidia-4-trillion-2026/' },
        { headline: 'Bitcoin consolidates near $95,000 as ETF inflows slow', summary: 'Bitcoin traded in a tight range near $95,000 as spot ETF inflows moderated, with analysts watching key support levels ahead of the next halving cycle.', url: 'https://finance.yahoo.com/news/bitcoin-etf-2026/' },
        { headline: 'US Treasury yields climb to 4.7% as strong jobs data dims rate-cut hopes', summary: 'Treasury yields jumped to multi-month highs after the March jobs report showed nonfarm payrolls beat forecasts by a wide margin, pushing back Fed easing expectations.', url: 'https://finance.yahoo.com/news/treasury-yields-jobs-2026/' },
        { headline: 'Apple unveils AI-powered iPhone 18 with on-device reasoning model', summary: 'Apple announced its next-generation iPhone featuring a fully on-device large language model capable of complex reasoning tasks without cloud connectivity.', url: 'https://finance.yahoo.com/news/apple-iphone18-ai-2026/' },
      ],
    },
    {
      site: { name: 'MarketWatch', category: '市場・経済' },
      articles: [
        { headline: 'US consumer confidence drops to 6-month low on tariff and inflation fears', summary: 'The Conference Board index fell sharply in March as Americans grew more pessimistic about the economic outlook amid new trade levies and stubborn price pressures.', url: 'https://www.marketwatch.com/story/consumer-confidence-march-2026/' },
        { headline: 'Gold hits record $3,200 per ounce as geopolitical tensions escalate', summary: 'Gold surged to a fresh all-time high as investors sought safe-haven assets amid heightened tensions in the Middle East and uncertainty over central bank policy plans.', url: 'https://www.marketwatch.com/story/gold-record-3200-2026/' },
        { headline: 'US housing starts fall 8% in February amid high mortgage rate headwinds', summary: 'New residential construction dropped sharply last month as elevated borrowing costs continued to suppress homebuilder activity and affordability for buyers.', url: 'https://www.marketwatch.com/story/housing-starts-feb-2026/' },
        { headline: 'Microsoft Azure revenue grows 32% as enterprise AI adoption accelerates', summary: 'Microsoft reported strong cloud growth as businesses increasingly embedded generative AI tools into core workflows, driving demand for Azure AI services.', url: 'https://www.marketwatch.com/story/microsoft-azure-ai-2026/' },
        { headline: 'Dollar index hits 2-year high on divergent central bank policy outlook', summary: 'The US dollar strengthened broadly as markets priced in a wider rate differential between the Fed and other major central banks including the ECB and BOE.', url: 'https://www.marketwatch.com/story/dollar-index-2026/' },
      ],
    },
    {
      site: { name: 'CNBC Economy', category: '経済・政策' },
      articles: [
        { headline: 'Trump administration unveils sweeping tariff package on imports from 40 countries', summary: 'The White House announced broad new import duties averaging 20%, targeting manufactured goods from Asia and Europe in what officials called a historic trade rebalancing.', url: 'https://www.cnbc.com/2026/03/27/trump-tariffs-40-countries.html' },
        { headline: 'IMF cuts 2026 global growth forecast to 3.1% citing trade war risks', summary: 'The International Monetary Fund lowered its world economic outlook for the second consecutive quarter, warning that protectionist policies could shave a full percentage point off global GDP.', url: 'https://www.cnbc.com/2026/03/27/imf-global-growth-forecast-2026.html' },
        { headline: 'US inflation CPI rises 2.9% year-over-year in February, above expectations', summary: "Consumer prices climbed more than expected last month, driven by services inflation and energy costs, complicating the Federal Reserve's path toward rate cuts.", url: 'https://www.cnbc.com/2026/03/27/us-cpi-february-2026.html' },
        { headline: 'Senate passes $2.5 trillion budget reconciliation bill, heads to House', summary: 'The Senate approved a sweeping fiscal package combining tax extensions and spending cuts, setting up a contentious debate in the House over deficit implications.', url: 'https://www.cnbc.com/2026/03/27/senate-budget-reconciliation-2026.html' },
        { headline: 'EV sales growth slows globally as incentive cuts take effect in major markets', summary: "Electric vehicle adoption decelerated in the first quarter as several governments phased out consumer subsidies, raising questions about the industry's growth trajectory.", url: 'https://www.cnbc.com/2026/03/27/ev-sales-slowdown-2026.html' },
      ],
    },
    {
      site: { name: 'BBC Business', category: '経済・国際政治' },
      articles: [
        { headline: 'UK economy narrowly avoids recession with 0.1% growth in Q4 2025', summary: "Britain's economy eked out marginal growth in the final quarter of last year, averting a technical recession but underscoring persistent weakness in the industrial and retail sectors.", url: 'https://www.bbc.com/news/business/uk-gdp-q4-2025' },
        { headline: 'Germany unveils €200bn defence and infrastructure spending plan', summary: "The German government announced a historic investment package funded by a constitutional reform, representing Berlin's biggest fiscal shift in decades.", url: 'https://www.bbc.com/news/business/germany-spending-2026' },
        { headline: "India overtakes Japan to become world's fourth-largest economy", summary: "India's GDP surpassed Japan's in nominal dollar terms for the first time, cementing its position as one of the world's fastest-growing major economies.", url: 'https://www.bbc.com/news/business/india-japan-gdp-2026' },
        { headline: 'Global shipping costs surge 40% as Red Sea disruptions persist', summary: 'Container freight rates spiked again as ongoing security concerns in the Red Sea forced shipping companies to reroute vessels around the Cape of Good Hope.', url: 'https://www.bbc.com/news/business/shipping-red-sea-2026' },
        { headline: 'ECB cuts rates for third time, signals more easing ahead as eurozone growth stalls', summary: 'The European Central Bank lowered its deposit rate by 25 basis points and hinted at further reductions as inflation in the eurozone returned to target while growth remained sluggish.', url: 'https://www.bbc.com/news/business/ecb-rate-cut-march-2026' },
      ],
    },
  ];

  const now = new Date().toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo' });
  console.log('='.repeat(60));
  console.log('  金融・経済・政治ニュース スクレイパー (Playwright)');
  console.log(`  実行日時: ${now} JST`);
  console.log('  ※ デモモード（--demo フラグ）で実行中');
  console.log('='.repeat(60));

  for (const { site, articles } of DEMO_DATA) {
    console.log(`\n${'─'.repeat(60)}`);
    console.log(`【${site.name}】 (${site.category})`);
    console.log('─'.repeat(60));
    articles.forEach((a, i) => {
      console.log(`\n  ${i + 1}. ${a.headline}`);
      console.log(`     概要: ${a.summary}`);
      console.log(`     URL: ${a.url}`);
    });
  }

  console.log('\n' + '='.repeat(60));
  console.log('  [LLM INPUT] 全取得記事（JSON形式）');
  console.log('='.repeat(60));
  console.log(JSON.stringify(DEMO_DATA, null, 2));
  return DEMO_DATA;
}

(async () => {
  const isDemo = process.argv.includes('--demo');
  if (isDemo) {
    runDemo();
  } else {
    try {
      await runLive();
    } catch (err) {
      console.error('\n[FATAL ERROR]', err.message);
      console.error('ヒント: ブラウザが未インストールの場合は "npx playwright install chromium" を実行してください');
      console.error('デモモードで再試行: node scrape_news.js --demo');
      process.exit(1);
    }
  }
})();
