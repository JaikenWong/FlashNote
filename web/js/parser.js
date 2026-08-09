// web/js/parser.js
// 与 Mac Parser.swift / 小程序 parser.js 完全一致

const AMOUNT_PATTERNS = [
  /¥\s*(\d+(?:\.\d+)?)/,
  /￥\s*(\d+(?:\.\d+)?)/,
  /(\d+(?:\.\d+)?)\s*元/,
  /\b(\d+(?:\.\d+)?)\b/
];
const TAG_REGEX = /#([\u4e00-\u9fa5\w_]+)/g;

export function parse(input, deviceId) {
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

  // 抽标签
  TAG_REGEX.lastIndex = 0;
  const allMatches = [];
  let m;
  while ((m = TAG_REGEX.exec(text)) !== null) {
    allMatches.push({ tag: m[1], start: m.index, end: m.index + m[0].length });
  }
  const seen = new Set();
  const tags = [];
  for (const match of allMatches) {
    if (!seen.has(match.tag)) {
      seen.add(match.tag);
      tags.push(match.tag);
    }
  }
  for (let i = allMatches.length - 1; i >= 0; i--) {
    text = text.slice(0, allMatches[i].start) + text.slice(allMatches[i].end);
  }

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
  // 用 crypto.randomUUID() 生成 RFC 4122 标准的 UUID v4
  // Mac 端 Record.id 是 UUID 类型，必须严格匹配才能被 handlePush 接受
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  // 兜底：极端环境下用 Math.random 凑一个 v4
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.random() * 16 | 0;
    return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
  });
}
