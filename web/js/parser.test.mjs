// 运行：node --test web/js/parser.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { extractDate } from './parser.js';

// 固定「现在」= 2026-08-09 周日 12:00（本地时区）
const NOW = new Date(2026, 7, 9, 12, 0, 0);

function ymd(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function expectDate(input, expectedYmd) {
  const { date } = extractDate(input, NOW);
  assert.equal(ymd(date), expectedYmd, `${input} → ${expectedYmd}`);
}

test('今天 / 昨天 / 前天 / N天前', () => {
  expectDate('今天午饭', '2026-08-09');
  expectDate('昨天晚饭', '2026-08-08');
  expectDate('前天打车', '2026-08-07');
  expectDate('3天前咖啡', '2026-08-06');
});

test('上周X（周一起始自然周，周日报上周三 = 11 天前）', () => {
  expectDate('上周三超市', '2026-07-29');
  expectDate('上周日', '2026-08-02');
  expectDate('上周末', '2026-08-01');
});

test('上N周X 的 N 生效', () => {
  expectDate('上三周三超市', '2026-07-15');   // 3 周前的周三
  expectDate('上五周六咖啡', '2026-07-04');   // 5 周前的周六
});

test('周X（无上字）取最近一个已过的周X', () => {
  // 周日说周三 → 本周三已过 = 8/5
  expectDate('周三开会', '2026-08-05');
});

test('M月D日 / M-D / M/D', () => {
  expectDate('3月5日咖啡', '2026-03-05');
  expectDate('3-5咖啡', '2026-03-05');
  expectDate('3/5咖啡', '2026-03-05');
});

test('M月D日超过今天 → 去年', () => {
  expectDate('8月30日聚会', '2025-08-30');
});

test('YYYY-MM-DD 优先于 M月D日，不被劫持', () => {
  expectDate('2026-08-01房租', '2026-08-01');
  expectDate('2012-5-3午饭', '2012-05-03');
  expectDate('2011-12-3房租', '2011-12-03');
});

test('无日期关键词 → 当前时间', () => {
  expectDate('午饭 30', '2026-08-09');
});
