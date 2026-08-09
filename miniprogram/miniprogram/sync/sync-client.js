// utils/sync-client.js
// 与 Mac 端 SyncServer 协议对齐
// API：info / pair / pull / push

const { loadAll, saveAll } = require('./storage.js');

const PORT = 9527;

/**
 * 把 host 解析成可用的 baseURL
 * 优先用传入的 host，否则扫到的 IP
 */
function makeBaseURL(host) {
  if (!host) throw new Error('host required');
  if (host.startsWith('http://') || host.startsWith('https://')) return host;
  return `http://${host}:${PORT}`;
}

function getInfo(host) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${makeBaseURL(host)}/api/info`,
      method: 'GET',
      timeout: 3000,
      success: (res) => {
        if (res.statusCode === 200) resolve(res.data);
        else reject(new Error(`status ${res.statusCode}`));
      },
      fail: (err) => reject(err)
    });
  });
}

function pair(host, code, deviceId, deviceName) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${makeBaseURL(host)}/api/pair`,
      method: 'POST',
      data: { code, deviceId, deviceName },
      timeout: 3000,
      success: (res) => {
        if (res.statusCode === 200) resolve(res.data);
        else reject(new Error(`status ${res.statusCode}: ${JSON.stringify(res.data)}`));
      },
      fail: reject
    });
  });
}

function pull(host, token, since, deviceId) {
  const sinceStr = since ? new Date(since).toISOString() : '1970-01-01T00:00:00Z';
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${makeBaseURL(host)}/api/records?since=${encodeURIComponent(sinceStr)}&deviceId=${encodeURIComponent(deviceId)}`,
      method: 'GET',
      timeout: 5000,
      header: { Authorization: `Bearer ${token}` },
      success: (res) => {
        if (res.statusCode === 200) resolve(res.data);
        else reject(new Error(`status ${res.statusCode}`));
      },
      fail: reject
    });
  });
}

function push(host, token, deviceId, changes) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${makeBaseURL(host)}/api/records`,
      method: 'POST',
      data: { deviceId, changes },
      timeout: 5000,
      header: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      success: (res) => {
        if (res.statusCode === 200) resolve(res.data);
        else reject(new Error(`status ${res.statusCode}`));
      },
      fail: reject
    });
  });
}

module.exports = { getInfo, pair, pull, push, makeBaseURL };
