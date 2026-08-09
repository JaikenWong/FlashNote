// utils/sync-coordinator.js
// 同步协调器：负责 pull + push + 合并（LWW）
// 由页面在 onShow 触发同步

const { loadAll, saveAll } = require('./storage.js');
const client = require('./sync-client.js');

const KEY_TOKEN = 'flashnote.syncToken';
const KEY_HOST = 'flashnote.syncHost';

function getToken() { return wx.getStorageSync(KEY_TOKEN) || ''; }
function setToken(t) { wx.setStorageSync(KEY_TOKEN, t); }
function clearToken() { wx.removeStorageSync(KEY_TOKEN); }
function getHost() { return wx.getStorageSync(KEY_HOST) || ''; }
function setHost(h) { wx.setStorageSync(KEY_HOST, h); }

/**
 * 完整一次同步
 * @returns {Promise<{pulled:number, pushed:number, error:?string}>}
 */
async function syncOnce({ deviceId, deviceName }) {
  const host = getHost();
  const token = getToken();
  if (!host || !token) {
    return { pulled: 0, pushed: 0, error: '未配对' };
  }

  try {
    // 1. 拉取
    const local = loadAll();
    const lastSync = local.reduce((max, r) => {
      const t = new Date(r.updatedAt).getTime();
      return t > max ? t : max;
    }, 0);
    const pullResp = await client.pull(host, token, lastSync || 0, deviceId);
    const remoteChanges = pullResp.changes || [];

    // 2. 合并到本地
    if (remoteChanges.length > 0) {
      mergeRecords(remoteChanges);
    }

    // 3. 推送本地比 server 新的
    const localAfter = loadAll();
    const lastRemoteSync = new Date(pullResp.serverTime).getTime();
    const toPush = localAfter.filter(r => {
      const t = new Date(r.updatedAt).getTime();
      return t > lastRemoteSync && r.deviceId === deviceId;
    });
    let pushed = 0;
    if (toPush.length > 0) {
      const pushResp = await client.push(host, token, deviceId, toPush);
      pushed = (pushResp.accepted || []).length;
    }

    return { pulled: remoteChanges.length, pushed, error: null };
  } catch (e) {
    return { pulled: 0, pushed: 0, error: e.message || String(e) };
  }
}

/**
 * LWW 合并远端记录
 */
function mergeRecords(remoteList) {
  const local = loadAll();
  const byId = {};
  for (const r of local) byId[r.id] = r;

  for (const incoming of remoteList) {
    const existing = byId[incoming.id];
    if (!existing) {
      byId[incoming.id] = incoming;
    } else {
      const t1 = new Date(existing.updatedAt).getTime();
      const t2 = new Date(incoming.updatedAt).getTime();
      if (t2 > t1) {
        byId[incoming.id] = incoming;
      }
    }
  }

  const merged = Object.values(byId);
  // 按 createdAt 倒序
  merged.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  saveAll(merged);
}

async function pairWithCode({ host, code, deviceId, deviceName }) {
  const resp = await client.pair(host, code, deviceId, deviceName);
  setToken(resp.token);
  setHost(host);
  return resp;
}

function unpair() {
  clearToken();
  wx.removeStorageSync(KEY_HOST);
}

function isPaired() {
  return !!(getToken() && getHost());
}

module.exports = {
  syncOnce,
  pairWithCode,
  unpair,
  isPaired,
  getHost,
  getToken
};
