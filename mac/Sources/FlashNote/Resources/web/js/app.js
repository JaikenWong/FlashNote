// web/js/app.js
// 主控制器：渲染列表、解析预览、提交、删、同步、配对

import { parse } from './parser.js';
import {
  loadAll, saveAll, add, softDelete,
  getOrCreateDeviceId, getServer, setServer,
  getToken, setToken, clearToken, isPaired
} from './storage.js';
import { getInfo, syncOnce, pair as pairRequest } from './sync.js';
import { compute as computeStats, render as renderStatsHtml } from './stats.js';

// 状态
let draft = '';
let records = [];

// DOM
const $ = id => document.getElementById(id);
const inputEl = $('input');
const sendBtn = $('sendBtn');
const listEl = $('list');
const emptyEl = $('empty');
const previewEl = $('preview');
const previewAmount = $('previewAmount');
const previewTags = $('previewTags');
const previewType = $('previewType');
const syncPill = $('syncPill');
const syncText = $('syncText');
const pairMask = $('pairMask');
const pairInput = $('pairInput');
const pairBtn = $('pairBtn');
const pairSkip = $('pairSkip');
const pairError = $('pairError');
const tabList = $('tabList');
const tabStats = $('tabStats');
const mainEl = $('main');
const statsMainEl = $('statsMain');
const statsContentEl = $('statsContent');

// ===== 初始化 =====
const deviceId = getOrCreateDeviceId();
console.log('[闪记] deviceId =', deviceId, 'server =', getServer());

// 先渲染本地记录
refresh();

// 检测 server 可达性 + 配对状态
bootstrap();

inputEl.addEventListener('input', e => {
  draft = e.target.value;
  renderPreview();
});
inputEl.addEventListener('keydown', e => {
  if (e.key === 'Enter') {
    e.preventDefault();
    submit();
  }
});
sendBtn.addEventListener('click', submit);
syncPill.addEventListener('click', () => doSync(true));

// Tab 切换
tabList.addEventListener('click', () => switchTab('list'));
tabStats.addEventListener('click', () => switchTab('stats'));

// 网络恢复后自动同步
window.addEventListener('online', () => doSync(false));

// 配对 UI
pairBtn.addEventListener('click', doPair);
pairInput.addEventListener('input', e => {
  pairError.hidden = true;
  pairBtn.disabled = !/^\d{4}$/.test(e.target.value);
});
pairInput.addEventListener('keydown', e => {
  if (e.key === 'Enter') { e.preventDefault(); doPair(); }
});
pairSkip.addEventListener('click', () => {
  pairMask.hidden = true;
  setSyncState('idle', '离线');
});

async function bootstrap() {
  try {
    const info = await getInfo();
    console.log('[闪记] server info:', info);
    if (!isPaired()) {
      // 自动用 server 上的配对码尝试（仅当用户在 Mac 上开 web）
      // 否则显示配对 modal
      if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
        showPairModal(info);
      } else {
        showPairModal(info);
      }
    } else {
      pairMask.hidden = true;
      doSync(false);
    }
  } catch (e) {
    console.warn('[闪记] server unreachable:', e);
    setSyncState('error', 'Mac 未连接');
    if (!isPaired()) {
      // 还是显示 modal，让用户能改 server 地址（输入新 IP）
      showPairModal();
    }
  }
}

function showPairModal() {
  pairMask.hidden = false;
  pairInput.value = '';
  pairError.hidden = true;
  pairBtn.disabled = true;
  setTimeout(() => pairInput.focus(), 100);
}

async function doPair() {
  const code = pairInput.value.trim();
  if (!/^\d{4}$/.test(code)) return;
  pairBtn.disabled = true;
  pairBtn.textContent = '连接中…';
  pairError.hidden = true;
  try {
    const name = navigator.userAgent.includes('iPhone') ? 'iPhone Safari'
              : navigator.userAgent.includes('Android') ? 'Android Browser'
              : 'Web Browser';
    await pairRequest(code, deviceId, name);
    pairMask.hidden = true;
    setSyncState('synced', '已配对 · 同步中…');
    doSync(false);
  } catch (e) {
    pairError.textContent = '配对失败：' + (e.message || '请检查配对码');
    pairError.hidden = false;
    pairBtn.disabled = false;
    pairBtn.textContent = '连接';
  }
}

// ===== 列表渲染 =====
function refresh() {
  records = loadAll().filter(r => !r.deleted);
  render();
  renderStats();
}

function render() {
  if (records.length === 0) {
    listEl.innerHTML = '';
    emptyEl.style.display = '';
    return;
  }
  emptyEl.style.display = 'none';
  listEl.innerHTML = renderList(records);
}

// ===== Tab 切换 =====
let currentTab = 'list';
function switchTab(tab) {
  if (tab === currentTab) return;
  currentTab = tab;
  if (tab === 'list') {
    tabList.classList.add('active');
    tabStats.classList.remove('active');
    mainEl.hidden = false;
    statsMainEl.hidden = true;
  } else {
    tabStats.classList.add('active');
    tabList.classList.remove('active');
    mainEl.hidden = true;
    statsMainEl.hidden = false;
    renderStats();
  }
}

// ===== 统计渲染 =====
function renderStats() {
  const stats = computeStats(records);
  statsContentEl.innerHTML = renderStatsHtml(stats);
}

function renderList(rs) {
  const sorted = rs.slice().sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  const groups = {};
  const order = [];
  for (const r of sorted) {
    const d = new Date(r.createdAt);
    const key = `${d.getFullYear()}年${d.getMonth() + 1}月`;
    if (!groups[key]) { groups[key] = { day: key, sum: 0, records: [] }; order.push(key); }
    groups[key].records.push(r);
    if (r.amount) groups[key].sum += r.amount;
  }
  return order.map(k => {
    const g = groups[k];
    const sumHtml = g.sum > 0
      ? `<span class="sum">· 支出 <span class="v">¥${g.sum.toFixed(0)}</span></span>`
      : '';
    const cards = g.records.map(r => renderCard(r)).join('');
    return `<div class="day-head">${escapeHtml(g.day)}${sumHtml}</div>${cards}`;
  }).join('');
}

function renderCard(r) {
  const isExp = r.type === 'expense';
  const tagsHtml = r.tags.map(t => `<span class="tag-chip">#${escapeHtml(t)}</span>`).join('');
  const amountHtml = r.amount ? `<span class="amount">¥${r.amount.toFixed(2)}</span><span class="sep">·</span>` : '';
  const time = relTime(r.createdAt);
  return `
    <div class="card ${isExp ? 'expense' : ''}" data-id="${r.id}">
      ${r.content ? `<p class="text">${escapeHtml(r.content)}</p>` : ''}
      <div class="meta">
        ${amountHtml}${tagsHtml}
        <span class="time">${time}</span>
        <button class="del" data-act="del" data-id="${r.id}">删除</button>
      </div>
    </div>
  `;
}

listEl.addEventListener('click', e => {
  const btn = e.target.closest('[data-act]');
  if (!btn) return;
  const id = btn.dataset.id;
  if (btn.dataset.act === 'del') {
    if (confirm('删除这条记录？')) {
      softDelete(id);
      refresh();
      // 触发后台同步（让 Mac 端也知道删了）
      doSync(false);
    }
  }
});

// ===== 解析预览 =====
function renderPreview() {
  if (!draft.trim()) {
    previewEl.hidden = true;
    previewAmount.textContent = '';
    previewTags.innerHTML = '';
    previewType.textContent = '';
    sendBtn.disabled = true;
    return;
  }
  const preview = parse(draft, deviceId);
  if (!preview) {
    previewEl.hidden = true;
    sendBtn.disabled = true;
    return;
  }
  previewEl.hidden = false;
  previewAmount.textContent = preview.amount ? `¥${preview.amount.toFixed(2)}` : '';
  previewTags.innerHTML = preview.tags.slice(0, 4).map(t => `<span class="tag-chip">#${escapeHtml(t)}</span>`).join('');
  previewType.textContent = preview.type === 'expense' ? '账目' : '笔记';
  sendBtn.disabled = false;
}

// ===== 提交 =====
function submit() {
  const text = draft.trim();
  if (!text) return;
  const record = parse(text, deviceId);
  if (!record) return;
  add(record);
  draft = '';
  inputEl.value = '';
  renderPreview();
  refresh();
  // 推送到 Mac 端
  doSync(false);
}

// ===== 同步 =====
async function doSync(manual) {
  setSyncState('syncing');
  try {
    const result = await syncOnce(deviceId);
    setSyncState('synced', `拉取 ${result.pulled} · 推送 ${result.pushed} · ${manual ? '手动' : '刚刚'}`);
    refresh();
  } catch (e) {
    console.warn('[闪记] sync failed', e);
    setSyncState('error', e.message || '同步失败');
  }
}

function setSyncState(state, text) {
  syncPill.className = 'sync-pill ' + (state === 'synced' ? '' : state);
  if (state === 'synced' && text) {
    syncText.textContent = text;
  } else if (state === 'syncing') {
    syncText.textContent = '同步中…';
  } else if (state === 'error') {
    syncText.textContent = text || '同步失败';
  } else {
    syncText.textContent = '本地';
  }
}

// ===== 工具 =====
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

function relTime(iso) {
  const d = new Date(iso);
  const diff = (Date.now() - d.getTime()) / 1000;
  if (diff < 60) return '刚刚';
  if (diff < 3600) return `${Math.floor(diff / 60)}分钟前`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}小时前`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}天前`;
  return `${d.getMonth() + 1}月${d.getDate()}日`;
}

// 启动时检查 server
getInfo().then(info => {
  console.log('[闪记] server:', info);
}).catch(e => {
  console.warn('[闪记] server unreachable:', e);
  setSyncState('error', 'Mac 未连接');
});
