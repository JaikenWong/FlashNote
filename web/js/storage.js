// web/js/storage.js
// 用 localStorage 替代 wx.setStorageSync
// 与小程序 storage.js / Mac RecordStore 接口对齐

const KEY = 'flashnote.records';
const KEY_DEVICE = 'flashnote.deviceId';
const KEY_SERVER = 'flashnote.syncServer';
const KEY_TOKEN = 'flashnote.syncToken';
const KEY_SERVER_TIME = 'flashnote.lastSyncTime';

export function loadAll() {
  try {
    return JSON.parse(localStorage.getItem(KEY) || '[]');
  } catch (e) {
    return [];
  }
}

export function saveAll(records) {
  try {
    localStorage.setItem(KEY, JSON.stringify(records));
    return true;
  } catch (e) {
    return false;
  }
}

export function add(record) {
  const records = loadAll();
  records.unshift(record);
  saveAll(records);
  return record;
}

export function softDelete(id, deviceId) {
  const records = loadAll();
  const idx = records.findIndex(r => r.id === id);
  if (idx >= 0) {
    records[idx].deleted = true;
    records[idx].updatedAt = new Date().toISOString();
    // 所有权转移给当前设备，保证 sync 推送条件 r.deviceId === deviceId 能命中
    // （否则 Mac 源记录在 web 上删除后推不回 Mac）
    if (deviceId) records[idx].deviceId = deviceId;
    saveAll(records);
  }
}

// ====== 同步游标（记录上次成功拉取的服务端时间）======
export function getLastSyncTime() {
  return localStorage.getItem(KEY_SERVER_TIME) || '';
}
export function setLastSyncTime(t) {
  if (t) localStorage.setItem(KEY_SERVER_TIME, t);
}

export function hardDelete(id) {
  saveAll(loadAll().filter(r => r.id !== id));
}

// ====== 设备身份 ======
export function getOrCreateDeviceId() {
  let id = localStorage.getItem(KEY_DEVICE);
  if (!id) {
    id = 'web-' + Math.random().toString(36).slice(2, 6) + '-' + Math.random().toString(36).slice(2, 6);
    localStorage.setItem(KEY_DEVICE, id);
  }
  return id;
}

// ====== Mac server 入口 ======
export function getServer() {
  // 优先用 localStorage 里的，没的话用当前 origin
  return localStorage.getItem(KEY_SERVER) || `${location.protocol}//${location.host}`;
}
export function setServer(url) {
  localStorage.setItem(KEY_SERVER, url);
}

// ====== 同步 token ======
export function getToken() {
  return localStorage.getItem(KEY_TOKEN) || '';
}
export function setToken(t) {
  localStorage.setItem(KEY_TOKEN, t);
}
export function clearToken() {
  localStorage.removeItem(KEY_TOKEN);
}
export function isPaired() {
  return !!getToken();
}
