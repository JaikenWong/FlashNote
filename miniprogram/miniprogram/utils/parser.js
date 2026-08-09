// utils/parser.js
// 与 Mac 端 Parser.swift 保持一致：识别金额、#标签，剩余为内容
// 规则：
//   ¥\d+ / ￥\d+ / \d+元 / 纯数字  → 金额
//   #xxx                            → 标签
//   剩余文本                         → content
//   有金额 → expense，否则 → note

const AMOUNT_PATTERNS = [
  /¥\s*(\d+(?:\.\d+)?)/,
  /￥\s*(\d+(?:\.\d+)?)/,
  /(\d+(?:\.\d+)?)\s*元/,
  /\b(\d+(?:\.\d+)?)\b/
];

const TAG_REGEX = /#([\u4e00-\u9fa5\w_]+)/g;

function parse(input, deviceId) {
  const trimmed = (input || '').trim();
  if (!trimmed) return null;

  let text = trimmed;
  let amount = null;

  // 抽金额
  for (const p of AMOUNT_PATTERNS) {
    const m = text.match(p);
    if (m && m[1]) {
      amount = parseFloat(m[1]);
      text = text.replace(m[0], '');
      break;
    }
  }

  // 抽标签：先收集所有匹配位置，再保留第一次出现的作为 tag，删除所有 #xxx
  TAG_REGEX.lastIndex = 0;
  const allMatches = [];
  let m;
  while ((m = TAG_REGEX.exec(text)) !== null) {
    allMatches.push({ tag: m[1], start: m.index, end: m.index + m[0].length });
  }

  // tags：去重但保留用户书写顺序
  const seen = new Set();
  const tags = [];
  for (const match of allMatches) {
    if (!seen.has(match.tag)) {
      seen.add(match.tag);
      tags.push(match.tag);
    }
  }
  // 删除所有 #xxx（用原始 start/end，从右往左）
  for (let i = allMatches.length - 1; i >= 0; i--) {
    text = text.slice(0, allMatches[i].start) + text.slice(allMatches[i].end);
  }

  // 折叠空白
  const content = text.split(/\s+/).filter(Boolean).join(' ');

  return {
    id: genId(),
    type: amount !== null ? 'expense' : 'note',
    content,
    amount,
    tags,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    deviceId: deviceId || '',
    deleted: false
  };
}

function genId() {
  return 'r-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8);
}

module.exports = { parse, genId };
