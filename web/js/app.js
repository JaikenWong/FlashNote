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
let searchQuery = '';

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
const editMask = $('editMask');
const editText = $('editText');
const editPreview = $('editPreview');
const editAmount = $('editAmount');
const editTags = $('editTags');
const editType = $('editType');
const editClose = $('editClose');
const editCancel = $('editCancel');
const editSave = $('editSave');
const editDel = $('editDel');
const searchInput = $('searchInput');
const searchClear = $('searchClear');
const noMatchEl = $('noMatch');

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

// 搜索
searchInput.addEventListener('input', e => {
  searchQuery = e.target.value;
  searchClear.hidden = !searchQuery;
  render();
});
searchClear.addEventListener('click', () => {
  searchInput.value = '';
  searchQuery = '';
  searchClear.hidden = true;
  render();
  searchInput.focus();
});

// 编辑浮层
editClose.addEventListener('click', closeEdit);
editCancel.addEventListener('click', closeEdit);
editDel.addEventListener('click', deleteFromEdit);
editSave.addEventListener('click', saveEdit);
editText.addEventListener('input', renderEditPreview);
editMask.addEventListener('click', e => {
  if (e.target === editMask) closeEdit();   // 点遮罩关闭
});

// 网络状态：监听 online/offline 自动重试
window.addEventListener('online', () => {
  console.log('[闪记] network online, retry sync');
  if (isPaired()) doSync(false);
});
window.addEventListener('offline', () => {
  console.log('[闪记] network offline');
  setSyncState('offline', '离线 · 待重试');
});

// iOS Safari 的 online/offline 事件不靠谱（onLine 不准）：
// 回到前台时若已配对，主动重试一次
document.addEventListener('visibilitychange', () => {
  if (!document.hidden && navigator.onLine && isPaired()) {
    doSync(false);
  }
});

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
  const filtered = filterRecords(records, searchQuery);
  if (records.length === 0) {
    listEl.innerHTML = '';
    emptyEl.style.display = '';
    noMatchEl.hidden = true;
    return;
  }
  emptyEl.style.display = 'none';
  if (filtered.length === 0) {
    listEl.innerHTML = '';
    noMatchEl.hidden = false;
    return;
  }
  noMatchEl.hidden = true;
  listEl.innerHTML = renderList(filtered);
}

/** 搜索过滤：content / tags / amount */
function filterRecords(rs, q) {
  if (!q) return rs;
  const ql = q.toLowerCase().trim();
  if (!ql) return rs;
  return rs.filter(r => {
    if ((r.content || '').toLowerCase().includes(ql)) return true;
    if ((r.tags || []).some(t => t.toLowerCase().includes(ql))) return true;
    if (r.amount != null && String(r.amount).includes(ql)) return true;
    return false;
  });
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

// ===== 编辑浮层 =====
let editingRecord = null;  // 当前正在编辑的 record

function openEdit(id) {
  const r = records.find(x => x.id === id);
  if (!r) return;
  editingRecord = r;
  editText.value = composeText(r);
  renderEditPreview();
  editMask.hidden = false;
  // 下一帧聚焦（让动画先跑）
  setTimeout(() => editText.focus(), 50);
}

function closeEdit() {
  editMask.hidden = true;
  editingRecord = null;
  editText.value = '';
}

function renderEditPreview() {
  const text = editText.value;
  if (!text.trim()) {
    editPreview.hidden = true;
    editSave.disabled = true;
    return;
  }
  const preview = parse(text, deviceId);
  if (!preview) {
    editPreview.hidden = true;
    editSave.disabled = true;
    return;
  }
  editPreview.hidden = false;
  editAmount.textContent = preview.amount ? `¥${preview.amount.toFixed(2)}` : '';
  editTags.innerHTML = preview.tags.slice(0, 4).map(t => `<span class="tag-chip">#${escapeHtml(t)}</span>`).join('');
  editType.textContent = preview.type === 'expense' ? '账目' : '笔记';
  editSave.disabled = false;
}

function saveEdit() {
  if (!editingRecord) return;
  const text = editText.value.trim();
  if (!text) return;
  const parsed = parse(text, deviceId);
  if (!parsed) return;
  // 保留 id / createdAt；deviceId 改成当前 web（否则 sync filter 不到）
  // 更新其他字段 + updatedAt
  const updated = {
    id: editingRecord.id,
    type: parsed.type,
    content: parsed.content,
    amount: parsed.amount,
    tags: parsed.tags,
    createdAt: editingRecord.createdAt,
    updatedAt: new Date().toISOString(),
    deviceId: deviceId,
    deleted: false,
  };
  // 替换本地记录
  const all = loadAll();
  const idx = all.findIndex(r => r.id === updated.id);
  if (idx >= 0) {
    all[idx] = updated;
    saveAll(all);
  }
  closeEdit();
  refresh();
  doSync(false);
}

function deleteFromEdit() {
  if (!editingRecord) return;
  const id = editingRecord.id;
  closeEdit();
  softDelete(id, deviceId);
  refresh();
  showToast('已删除');
  doSync(false);
}

/** 把 record 反向 compose 成 text（与 mac/QuickRecordModal.composeText 对齐） */
function composeText(r) {
  const parts = [];
  if (r.amount) parts.push(`¥${r.amount}`);
  if (r.content) parts.push(r.content);
  for (const t of (r.tags || [])) parts.push(`#${t}`);
  return parts.join(' ');
}

function renderList(rs) {
  const sorted = rs.slice().sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  const groups = {};
  const order = [];
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterday = new Date(today.getTime() - 86400000);
  const weekStart = new Date(today.getTime() - 6 * 86400000);  // 本周 = 今天 + 前 6 天
  const yearStart = new Date(now.getFullYear(), 0, 1);

  for (const r of sorted) {
    const d = new Date(r.createdAt);
    const dayKey = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    const groupKey = pickGroupKey(d, today, yesterday, weekStart, yearStart);
    if (!groups[groupKey]) {
      groups[groupKey] = { label: groupKey, sum: 0, records: [] };
      order.push(groupKey);
    }
    groups[groupKey].records.push(r);
    if (r.amount) groups[groupKey].sum += r.amount;
  }
  return order.map(k => {
    const g = groups[k];
    const sumHtml = g.sum > 0
      ? `<span class="sum">· 支出 <span class="v">¥${g.sum.toFixed(0)}</span></span>`
      : '';
    const cards = g.records.map(r => renderCard(r)).join('');
    return `<div class="day-head">${escapeHtml(k)}${sumHtml}</div>${cards}`;
  }).join('');
}

function pickGroupKey(d, today, yesterday, weekStart, yearStart) {
  const day = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  if (day.getTime() === today.getTime()) return '今天';
  if (day.getTime() === yesterday.getTime()) return '昨天';
  if (day.getTime() >= weekStart.getTime() && day.getTime() < today.getTime()) {
    const wd = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][d.getDay()];
    return `本周·${wd}`;
  }
  if (day.getTime() >= yearStart.getTime()) {
    return `${d.getMonth() + 1}月${d.getDate()}日`;
  }
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`;
}

function renderCard(r) {
  const isExp = r.type === 'expense';
  const tagsHtml = r.tags.map(t => `<button class="tag-chip" data-tag="${escapeHtml(t)}">#${escapeHtml(t)}</button>`).join('');
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

// 长按删除：pointerdown 启动 800ms 计时，到时间才删除；中途松开取消
const LONG_PRESS_MS = 800;
let pressTimer = null;
let pressingBtn = null;
let suppressClick = false;  // 长按触发删除后，吞掉随后的 click（防误开编辑）

function startLongPress(btn) {
  cancelLongPress();
  btn.classList.add('pressing');
  pressingBtn = btn;
  pressTimer = setTimeout(() => {
    const id = btn.dataset.id;
    btn.classList.remove('pressing');
    pressingBtn = null;
    pressTimer = null;
    suppressClick = true;
    setTimeout(() => { suppressClick = false; }, 300);

    // 找到对应卡片，加 .deleting 触发 fade out；动画结束再真正删
    const card = btn.closest('.card');
    if (card) {
      card.classList.add('deleting');
      setTimeout(() => {
        softDelete(id, deviceId);
        refresh();
        doSync(false);
        showToast('已删除');
      }, 220);
    } else {
      softDelete(id, deviceId);
      refresh();
      doSync(false);
      showToast('已删除');
    }
  }, LONG_PRESS_MS);
}
function cancelLongPress() {
  if (pressTimer) { clearTimeout(pressTimer); pressTimer = null; }
  if (pressingBtn) { pressingBtn.classList.remove('pressing'); pressingBtn = null; }
}

listEl.addEventListener('pointerdown', e => {
  const delBtn = e.target.closest('[data-act="del"]');
  if (delBtn) {
    e.stopPropagation();
    e.preventDefault();  // 阻止 iOS Safari 的「长按弹出菜单」
    startLongPress(delBtn);
  }
});
// 无条件取消：pressing 时 del 按钮 pointer-events:none，指针事件打不到它，
// 按 target 过滤会漏掉（desktop 无隐式 pointer capture）。
// 松开 / 离开 / 取消 / 移出 任一都取消。
['pointerup', 'pointerleave', 'pointercancel', 'pointerout'].forEach(ev => {
  listEl.addEventListener(ev, () => {
    if (pressingBtn) cancelLongPress();
  });
});

listEl.addEventListener('click', e => {
  // 长按删除完成后的 click（发生在 refresh 重渲染后）——直接吞掉
  if (suppressClick) {
    suppressClick = false;
    e.stopPropagation();
    e.preventDefault();
    return;
  }
  // 阻止长按后 click 冒泡触发其他逻辑
  if (e.target.closest('[data-act="del"]')) {
    e.stopPropagation();
    e.preventDefault();
    return;
  }
  // 点标签 chip → 触发搜索（不打开编辑）
  const tagBtn = e.target.closest('.tag-chip');
  if (tagBtn) {
    e.stopPropagation();
    const t = tagBtn.dataset.tag;
    searchInput.value = t;
    searchQuery = t;
    searchClear.hidden = false;
    render();
    searchInput.focus();
    return;
  }
  // 点卡片本体（不在删除按钮上）→ 打开编辑
  const card = e.target.closest('.card');
  if (card) {
    openEdit(card.dataset.id);
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
  // 收键盘（iPhone 上提交后键盘留着会很烦）
  inputEl.blur();
  // 推送到 Mac 端
  doSync(false);
}

// ===== 同步 =====
async function doSync(manual) {
  if (!navigator.onLine) {
    setSyncState('offline', '离线 · 待重试');
    return;
  }
  setSyncState('syncing');
  try {
    const result = await syncOnce(deviceId);
    setSyncState('synced', `拉取 ${result.pulled} · 推送 ${result.pushed} · ${manual ? '手动' : '刚刚'}`);
    refresh();
  } catch (e) {
    console.warn('[闪记] sync failed', e);
    // 失败时区分：网络层错（fetch 拒绝）→ offline；其他（401、500）→ error
    const isNetwork = /failed to fetch|networkerror|abort/i.test(e.message || '');
    if (isNetwork || !navigator.onLine) {
      setSyncState('offline', '离线 · 待重试');
    } else {
      setSyncState('error', e.message || '同步失败');
    }
  }
}

function setSyncState(state, text) {
  // synced 状态保持空 class（绿色默认）；其他状态加 class
  syncPill.className = 'sync-pill ' + (state === 'synced' ? '' : state);
  // 无自定义文案时给默认中文
  const defaults = {
    syncing: '同步中…',
    offline: '离线 · 待重试',
    error: '同步失败',
    idle: '本地'
  };
  syncText.textContent = text || defaults[state] || state;
}

// ===== 工具 =====
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

// ====== Toast 提示 ======
let toastTimer = null;
function showToast(msg) {
  // 移除旧的
  document.querySelectorAll('.toast').forEach(t => t.remove());
  if (toastTimer) clearTimeout(toastTimer);
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = msg;
  document.body.appendChild(el);
  toastTimer = setTimeout(() => el.remove(), 1900);
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
