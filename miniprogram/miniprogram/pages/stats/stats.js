// pages/stats/stats.js
const storage = require('../../utils/storage.js');

Page({
  data: {
    monthLabel: '',
    totalAmount: '0',
    recordCount: 0,
    compare: '',         // 同比上月文字
    categories: [],      // [{name, amount, percent, color, icon}]
    weekBars: []         // 最近 7 天柱状
  },

  onShow() {
    this.refresh();
  },

  refresh() {
    const records = storage.loadAll().filter(r => !r.deleted);
    const now = new Date();
    const thisMonth = now.getMonth();
    const thisYear = now.getFullYear();

    const monthLabel = `${thisYear}年${thisMonth + 1}月`;
    const thisMonthRecords = records.filter(r => {
      const d = new Date(r.createdAt);
      return d.getFullYear() === thisYear && d.getMonth() === thisMonth;
    });

    const total = thisMonthRecords.reduce((s, r) => s + (r.amount || 0), 0);
    const count = thisMonthRecords.length;

    // 上月数据
    const lastMonth = thisMonth === 0 ? 11 : thisMonth - 1;
    const lastMonthYear = thisMonth === 0 ? thisYear - 1 : thisYear;
    const lastMonthTotal = records
      .filter(r => {
        const d = new Date(r.createdAt);
        return d.getFullYear() === lastMonthYear && d.getMonth() === lastMonth;
      })
      .reduce((s, r) => s + (r.amount || 0), 0);

    let compare = '';
    if (lastMonthTotal > 0) {
      const diff = ((total - lastMonthTotal) / lastMonthTotal * 100).toFixed(0);
      const arrow = total > lastMonthTotal ? '↑' : '↓';
      compare = `${arrow} ${Math.abs(diff)}% vs 上月`;
    } else if (total > 0) {
      compare = '本月新开始';
    }

    // 分类聚合（按 #标签）
    const catMap = {};
    for (const r of thisMonthRecords) {
      const cat = (r.tags[0] || '其他');
      catMap[cat] = (catMap[cat] || 0) + (r.amount || 0);
    }
    const cats = Object.keys(catMap)
      .map(name => ({
        name,
        amount: catMap[name].toFixed(0),
        raw: catMap[name],
        percent: total > 0 ? Math.round(catMap[name] / total * 100) : 0,
        color: pickColor(name)
      }))
      .sort((a, b) => b.raw - a.raw);

    // 最近 7 天
    const weekBars = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      d.setHours(0, 0, 0, 0);
      const next = new Date(d);
      next.setDate(d.getDate() + 1);
      const dayTotal = records
        .filter(r => {
          const rd = new Date(r.createdAt);
          return rd >= d && rd < next;
        })
        .reduce((s, r) => s + (r.amount || 0), 0);
      const label = i === 0 ? '今' : `${d.getDate()}`;
      weekBars.push({ label, amount: dayTotal, max: 0 });
    }
    const max = Math.max(...weekBars.map(b => b.amount), 1);
    weekBars.forEach(b => b.percent = Math.round(b.amount / max * 100));

    this.setData({
      monthLabel,
      totalAmount: total.toFixed(0),
      recordCount: count,
      compare,
      categories: cats,
      weekBars
    });
  }
});

function pickColor(name) {
  const palette = ['#52C41A', '#1677FF', '#FAAD14', '#722ED1', '#13C2C2', '#EB2F96', '#8C8C8C'];
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % palette.length;
  return palette[h];
}
