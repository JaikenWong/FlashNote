// web/js/sync.js
// 跟 Mac server 的 HTTP API 对话

import { loadAll, saveAll, getServer, getToken, setToken } from './storage.js';

const TIMEOUT_MS = 5000;

function fetchJSON(url, opts = {}) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  return fetch(url, { ...opts, signal: ctrl.signal })
    .then(async r => {
      if (!r.ok) {
        let msg = `HTTP ${r.status}`;
        try { const j = await r.json(); if (j.error) msg = j.error; } catch {}
        throw new Error(msg);
      }
      return r.json();
    })
    .finally(() => clearTimeout(t));
}

function authHeaders() {
  const t = getToken();
  return t ? { 'Authorization': `Bearer ${t}` } : {};
}

export function getInfo() {
  return fetchJSON(`${getServer()}/api/info`);
}

export function pair(code, deviceId, deviceName) {
  return fetchJSON(`${getServer()}/api/pair`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code, deviceId, deviceName })
  }).then(resp => {
    setToken(resp.token);
    return resp;
  });
}

export function pull(deviceId) {
  const local = loadAll();
  const since = local.reduce((m, r) => Math.max(m, new Date(r.updatedAt).getTime()), 0);
  const sinceStr = since ? new Date(since).toISOString() : '1970-01-01T00:00:00Z';
  return fetchJSON(
    `${getServer()}/api/records?since=${encodeURIComponent(sinceStr)}&deviceId=${encodeURIComponent(deviceId)}`,
    { headers: authHeaders() }
  );
}

export function push(deviceId, changes) {
  return fetchJSON(`${getServer()}/api/records`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify({ deviceId, changes })
  });
}

/**
 * 一次完整同步：先 pull，merge；再 push 本地比 server 新的
 * 任何错误都冒泡给调用方
 */
export async function syncOnce(deviceId) {
  // 1. 拉
  const pullResp = await pull(deviceId);
  const remote = pullResp.changes || [];

  // 2. 合并
  if (remote.length > 0) {
    mergeRecords(remote);
  }

  // 3. 推送本地比 server 新的
  const after = loadAll();
  const lastServer = new Date(pullResp.serverTime).getTime();
  const toPush = after.filter(r => {
    const t = new Date(r.updatedAt).getTime();
    return t > lastServer && r.deviceId === deviceId;
  });

  let pushed = 0;
  if (toPush.length > 0) {
    const pushResp = await push(deviceId, toPush);
    pushed = (pushResp.accepted || []).length;
  }

  return { pulled: remote.length, pushed };
}

/**
 * LWW 合并
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
      if (t2 > t1) byId[incoming.id] = incoming;
    }
  }
  const merged = Object.values(byId);
  merged.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  saveAll(merged);
}
