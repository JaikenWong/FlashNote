// utils/storage.js
// 本地存储封装（M2：纯本地；M3 叠加同步层）

const KEY = 'flashnote.records';

function loadAll() {
  try {
    return wx.getStorageSync(KEY) || [];
  } catch (e) {
    return [];
  }
}

function saveAll(records) {
  try {
    wx.setStorageSync(KEY, records);
    return true;
  } catch (e) {
    console.error('[闪记] 保存失败', e);
    return false;
  }
}

function add(record) {
  const records = loadAll();
  records.unshift(record);
  saveAll(records);
  return record;
}

function softDelete(id) {
  const records = loadAll();
  const idx = records.findIndex(r => r.id === id);
  if (idx >= 0) {
    records[idx].deleted = true;
    records[idx].updatedAt = new Date().toISOString();
    saveAll(records);
  }
}

function hardDelete(id) {
  const records = loadAll().filter(r => r.id !== id);
  saveAll(records);
}

function update(id, patch) {
  const records = loadAll();
  const idx = records.findIndex(r => r.id === id);
  if (idx >= 0) {
    records[idx] = Object.assign({}, records[idx], patch, {
      updatedAt: new Date().toISOString()
    });
    saveAll(records);
  }
}

module.exports = { loadAll, saveAll, add, softDelete, hardDelete, update };
