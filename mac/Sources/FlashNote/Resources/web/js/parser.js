// web/js/parser.js
// 与 Mac Parser.swift / 小程序 parser.js 解析规则一致
// 新增：日期识别（"昨天晚饭 65" → createdAt=昨天）

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

  // 抽日期（先于金额，否则「3天前」「8月5日」「2026-08-01」的数字会被当 amount 抓走）
  const { date, matched: dateMatched } = extractDate(text);
  if (dateMatched) {
    text = text.replace(dateMatched, ' ');
  }

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

  const createdAt = date.toISOString();
  return {
    id: genId(),
    type: amount !== null ? 'expense' : 'note',
    content,
    amount,
    tags,
    createdAt,
    updatedAt: createdAt,
    deviceId: deviceId || '',
    deleted: false
  };
}

/**
 * 从 input 抽取日期关键词，返回 { date, matched }
 * - date: Date 对象（基础日期，时分用「现在」）
 * - matched: 匹配到的文本（用于从 content 中剔除）
 * - 无关键词：date = now, matched = null
 *
 * 关键词（按优先级匹配）：
 *   今天 / 今早 / 今晚
 *   昨天 / 昨晚
 *   前天
 *   N 天前
 *   上周 X（X = 日一二三四五六天末）/ 上 N 周 X
 *   周 X（本周X 已过 = 上周X；未到 = 本周X）
 *   YYYY 年 M 月 D 日 / YYYY-M-D / YYYY/M/D（先于 M月D日，防劫持）
 *   M 月 D 日 / M-D / M/D（今年；超过今天则去年）
 */
export function extractDate(input, now = new Date()) {
  let date = now;
  let matched = null;

  // 1) 今天 / 今早 / 今晚
  if (/今[天早晚]/.test(input)) {
    matched = input.match(/今[天早晚]/)[0];
  }
  // 2) 昨天 / 昨晚
  else if (/昨[天晚]/.test(input)) {
    matched = input.match(/昨[天晚]/)[0];
    const d = new Date(now);
    d.setDate(d.getDate() - 1);
    date = d;
  }
  // 3) 前天
  else if (/前天/.test(input)) {
    matched = '前天';
    const d = new Date(now);
    d.setDate(d.getDate() - 2);
    date = d;
  }
  // 4) N 天前
  else {
    const m = input.match(/(\d+)\s*天前/);
    if (m) {
      matched = m[0];
      const n = parseInt(m[1], 10);
      const d = new Date(now);
      d.setDate(d.getDate() - n);
      date = d;
    }
  }

  // 5) 上周X / 上N周X（周一自然周）
  if (!matched) {
    const wdMap = { '日': 0, '天': 0, '末': 6, '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6 };
    const cnNum = { '一': 1, '二': 2, '三': 3, '四': 4, '五': 5 };
    const todayWd = now.getDay();
    // 距本周一几天（周一=0）：Sun=6, Mon=0, Tue=1, ... Sat=5
    const daysSinceMon = (todayWd + 6) % 7;
    // 先试 上N周X（如「上三周三」），再试 上周X
    let m = input.match(/上([一二三四五])周([日一二三四五六末天])/);
    if (!m) m = input.match(/上周([日一二三四五六末天])/);
    if (m) {
      matched = m[0];
      const N = m[2] ? (cnNum[m[1]] ?? 1) : 1;
      const wdChar = m[2] || m[1];
      const targetWd = wdMap[wdChar] ?? 0;
      // 目标相对周一偏移：一=0, 二=1, ... 日=6
      const relTarget = (targetWd + 6) % 7;
      const offset = daysSinceMon + 7 * N - relTarget;
      const d = new Date(now);
      d.setDate(d.getDate() - offset);
      date = d;
    }
  }

  // 6) 周 X（无"上"字）：未到 = 本周X；已过 = 上周X
  if (!matched) {
    const wdMap = { '日': 0, '天': 0, '末': 6, '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6 };
    const m = input.match(/(?<!上)周([日一二三四五六末天])/);
    if (m) {
      matched = m[0];
      const targetWd = wdMap[m[1]];
      const todayWd = now.getDay();
      // offset: targetWd - todayWd；若 targetWd > todayWd → 上周X（offset < 0）
      let offset = targetWd - todayWd;
      if (offset > 0) offset -= 7;  // 未来 → 上周
      const d = new Date(now);
      d.setDate(d.getDate() + offset);
      date = d;
    }
  }

  // 7) YYYY-MM-DD / YYYY/MM/DD / YYYY年M月D日（必须在 M月D日 之前匹配，
  //    否则 "2012-5-3" 会被 M月D日 抓成 "12-5" → 12月5日）
  if (!matched) {
    const m = input.match(/(\d{4})\s*[年\-\/]\s*(\d{1,2})\s*[月\-\/]\s*(\d{1,2})\s*[日号]?/);
    if (m) {
      matched = m[0];
      const Y = parseInt(m[1], 10);
      const M = parseInt(m[2], 10) - 1;
      const D = parseInt(m[3], 10);
      date = new Date(Y, M, D, now.getHours(), now.getMinutes(), now.getSeconds());
    }
  }

  // 8) M月D日 / M-D / M/D（前面不能是数字，避免吞掉 YYYY 的尾段如 "12-5"）
  if (!matched) {
    const m = input.match(/(?<!\d)(\d{1,2})\s*[月\-\/]\s*(\d{1,2})\s*[日号]?/);
    if (m) {
      const M = parseInt(m[1], 10);
      const D = parseInt(m[2], 10);
      // 校验：M 1-12，D 1-31（不严格校验每月天数，Date constructor 会处理）
      if (M >= 1 && M <= 12 && D >= 1 && D <= 31) {
        matched = m[0];
        const year = now.getFullYear();
        let d = new Date(year, M - 1, D, now.getHours(), now.getMinutes(), now.getSeconds());
        // 超过今天 → 去年
        if (d.getTime() > now.getTime()) {
          d = new Date(year - 1, M - 1, D, now.getHours(), now.getMinutes(), now.getSeconds());
        }
        date = d;
      }
    }
  }

  return { date, matched };
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
