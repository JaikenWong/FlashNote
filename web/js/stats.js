// web/js/stats.js
// 统计计算 + 渲染：与 mac/Store/StatisticsStore.swift 逻辑对齐

const PALETTE = [
  '#52C41A', // 主绿
  '#1772F6', // 蓝
  '#FAAD14', // 橙
  '#742EDB', // 紫
  '#13C2C2', // 青
  '#EB2F96', // 粉
  '#8C8C8C'  // 灰
];

function colorFor(name) {
  let h = 5381;
  for (const c of name) {
    h = ((h << 5) + h + c.charCodeAt(0)) | 0;
  }
  return PALETTE[Math.abs(h) % PALETTE.length];
}

/** 计算 Statistics（结构对齐 mac StatisticsStore.Statistics） */
export function compute(records, ref = new Date()) {
  const visible = records.filter(r => !r.deleted);
  const now = new Date(ref);
  const y = now.getFullYear();
  const m = now.getMonth();

  const sameMonth = r => {
    const d = new Date(r.createdAt);
    return d.getFullYear() === y && d.getMonth() === m;
  };
  const lastMonthRef = new Date(y, m - 1, 1);
  const ly = lastMonthRef.getFullYear();
  const lm = lastMonthRef.getMonth();
  const sameLastMonth = r => {
    const d = new Date(r.createdAt);
    return d.getFullYear() === ly && d.getMonth() === lm;
  };

  const thisMonth = visible.filter(sameMonth);
  const monthTotal = thisMonth.reduce((s, r) => s + (r.amount || 0), 0);
  const monthCount = thisMonth.length;

  const lastTotal = visible.filter(sameLastMonth).reduce((s, r) => s + (r.amount || 0), 0);
  const monthDeltaPercent = lastTotal > 0 ? (monthTotal - lastTotal) / lastTotal * 100 : null;

  // 分类（按 tags 第一个聚合）
  const catMap = {};
  for (const r of thisMonth) {
    const cat = (r.tags && r.tags[0]) || '其他';
    catMap[cat] = (catMap[cat] || 0) + (r.amount || 0);
  }
  const categories = Object.entries(catMap)
    .sort((a, b) => b[1] - a[1])
    .map(([name, amount]) => ({
      name,
      amount,
      percent: monthTotal > 0 ? (amount / monthTotal) * 100 : 0,
      color: colorFor(name)
    }));

  // 最近 7 天（含今天）
  const weekBars = [];
  const startOfDay = d => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  for (let i = 6; i >= 0; i--) {
    const d = new Date(y, m, now.getDate() - i);
    const s = startOfDay(d);
    const e = s + 86400000;
    const dayRecords = visible.filter(r => {
      const t = new Date(r.createdAt).getTime();
      return t >= s && t < e;
    });
    const amt = dayRecords.reduce((sum, r) => sum + (r.amount || 0), 0);
    weekBars.push({
      date: d,
      label: i === 0 ? '今' : String(d.getDate()),
      amount: amt,
      percent: 0
    });
  }
  const maxAmt = Math.max(1, ...weekBars.map(b => b.amount));
  weekBars.forEach(b => { b.percent = (b.amount / maxAmt) * 100; });

  // 全部标签 Top 10
  const tagMap = {};
  for (const r of visible) {
    for (const t of (r.tags || [])) {
      tagMap[t] = (tagMap[t] || 0) + 1;
    }
  }
  const topTags = Object.entries(tagMap)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([name, count]) => ({ name, count }));

  // 月份标签
  const monthLabel = `${y} 年 ${m + 1} 月`;

  return {
    monthLabel,
    monthTotal,
    monthCount,
    monthDeltaPercent,
    categories,
    weekBars,
    topTags
  };
}

// ===== 渲染（返回 HTML 字符串，host 页面负责塞进 DOM） =====

export function render(stats) {
  const empty = stats.monthTotal === 0 && stats.monthCount === 0;
  if (empty) {
    return `<div class="stats-empty">
      <div class="emoji">📊</div>
      <div>本月还没有数据</div>
      <div class="hint">记几笔「午饭 28 #餐」再来看看</div>
    </div>`;
  }

  return `
    <div class="stats-page">
      <div class="stats-month">${stats.monthLabel}</div>

      <div class="big-cards">
        <div class="big-card">
          <div class="big-label">本月支出</div>
          <div class="big-value">¥${stats.monthTotal.toFixed(0)}</div>
          <div class="big-sub" style="color:${(stats.monthDeltaPercent ?? 0) >= 0 ? '#FAAD14' : '#389E0D'}">
            ${stats.monthDeltaPercent != null
              ? `${stats.monthDeltaPercent >= 0 ? '↑' : '↓'} ${Math.abs(stats.monthDeltaPercent).toFixed(0)}% vs 上月`
              : '无对比数据'}
          </div>
        </div>
        <div class="big-card">
          <div class="big-label">记录数</div>
          <div class="big-value">${stats.monthCount}</div>
          <div class="big-sub" style="color:#8C8C8C">笔 · 全部类型</div>
        </div>
      </div>

      ${stats.categories.length > 0 ? `
        <div class="stats-section">
          <div class="section-title">分类占比</div>
          <div class="cat-card">
            <div class="donut-wrap">
              ${donutSvg(stats.categories)}
            </div>
            <div class="cat-list">
              ${stats.categories.slice(0, 5).map(catRow).join('')}
            </div>
          </div>
        </div>
      ` : ''}

      <div class="stats-section">
        <div class="section-title">最近 7 天</div>
        <div class="week-card">
          <div class="week-bars">
            ${stats.weekBars.map(b => weekBar(b)).join('')}
          </div>
        </div>
      </div>

      ${stats.topTags.length > 0 ? `
        <div class="stats-section">
          <div class="section-title">热门标签</div>
          <div class="tags-card">
            ${stats.topTags.map(tagChip).join('')}
          </div>
        </div>
      ` : ''}
    </div>
  `;
}

function catRow(c) {
  return `<div class="cat-row">
    <span class="cat-dot" style="background:${c.color}"></span>
    <span class="cat-name">${escape(c.name)}</span>
    <span class="cat-amount">¥${c.amount.toFixed(0)}</span>
  </div>`;
}

function weekBar(b) {
  const isToday = b.label === '今';
  const h = Math.max(4, b.percent * 0.6); // 60px max
  return `<div class="week-bar">
    <div class="bar-track">
      <div class="bar-fill ${isToday ? 'today' : ''}" style="height:${h}%"></div>
    </div>
    <div class="bar-label ${isToday ? 'today' : ''}">${b.label}</div>
  </div>`;
}

function tagChip(t) {
  return `<div class="tag-pill">
    <span class="tag-name">#${escape(t.name)}</span>
    <span class="tag-count">${t.count}</span>
  </div>`;
}

/** SVG donut */
function donutSvg(categories) {
  const total = categories.reduce((s, c) => s + c.percent, 0);
  if (total <= 0) return '';
  const R = 38, C = 50;
  const cx = C, cy = C;
  let acc = 0;
  const segs = categories.map(c => {
    const start = acc / total;
    acc += c.percent;
    const end = acc / total;
    return arcPath(cx, cy, R, start, end, c.color);
  }).join('');
  const lead = categories[0];
  return `<svg viewBox="0 0 ${C * 2} ${C * 2}" width="110" height="110">
    <circle cx="${cx}" cy="${cy}" r="${R}" fill="none" stroke="#F0F0F0" stroke-width="12"/>
    ${segs}
    <text x="${cx}" y="${cy - 2}" text-anchor="middle" font-size="16" font-weight="600" fill="#1F1F1F">${Math.round(lead.percent)}%</text>
    <text x="${cx}" y="${cy + 14}" text-anchor="middle" font-size="10" fill="#8C8C8C">${escape(lead.name)}</text>
  </svg>`;
}

/** 圆弧 path：start/end 都是 0-1 比例，0 在 12 点钟方向 */
function arcPath(cx, cy, r, start, end, color) {
  if (end - start >= 0.9999) {
    // 完整圆：用两条半弧
    return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${color}" stroke-width="12"/>`;
  }
  const a0 = (start - 0.25) * Math.PI * 2;
  const a1 = (end - 0.25) * Math.PI * 2;
  const x0 = cx + r * Math.cos(a0);
  const y0 = cy + r * Math.sin(a0);
  const x1 = cx + r * Math.cos(a1);
  const y1 = cy + r * Math.sin(a1);
  const large = (end - start) > 0.5 ? 1 : 0;
  return `<path d="M ${x0} ${y0} A ${r} ${r} 0 ${large} 1 ${x1} ${y1}" fill="none" stroke="${color}" stroke-width="12" stroke-linecap="butt"/>`;
}

function escape(s) {
  return String(s).replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}
