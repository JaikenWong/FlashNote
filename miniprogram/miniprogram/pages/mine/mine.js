// pages/mine/mine.js
const app = getApp();
const storage = require('../../utils/storage.js');
const { getDeviceInfo } = require('../../utils/device.js');
const sync = require('../../sync/coordinator.js');
const discovery = require('../../sync/discovery.js');
const syncClient = require('../../sync/sync-client.js');

Page({
  data: {
    deviceId: '',
    deviceInfo: '',
    recordCount: 0,
    pairStep: 'idle',     // idle | scanning | entering | pairing | paired | error
    pairCode: '',
    pairHost: '',
    pairError: '',
    discoveredHosts: [],
    lastSyncText: '从未同步',
    syncState: 'idle'      // idle | syncing | synced | error
  },

  onShow() {
    this.refresh();
    // 如果已配对，自动同步
    if (sync.isPaired()) {
      this.doSync();
    }
  },

  onUnload() {
    discovery.stopDiscovery();
  },

  refresh() {
    const records = storage.loadAll().filter(r => !r.deleted);
    const info = getDeviceInfo();
    this.setData({
      deviceId: app.globalData.deviceId,
      deviceInfo: info.model || '微信小程序',
      recordCount: records.length,
      pairStep: sync.isPaired() ? 'paired' : 'idle',
      pairHost: sync.getHost() || ''
    });
  },

  // 进入配对流程
  async onStartPair() {
    this.setData({ pairStep: 'scanning', pairError: '', discoveredHosts: [] });
    try {
      const hosts = await discovery.startDiscovery();
      if (hosts.length === 0) {
        // 没扫到 → 让用户手输 IP
        this.setData({ pairStep: 'entering' });
      } else {
        this.setData({ discoveredHosts: hosts, pairStep: 'entering' });
      }
    } catch (e) {
      this.setData({ pairStep: 'entering', pairError: 'mDNS 扫描失败，请手动输入 Mac IP' });
    }
  },

  onSelectHost(e) {
    const host = e.currentTarget.dataset.host;
    this.setData({ pairHost: host });
  },

  onInputHost(e) {
    this.setData({ pairHost: e.detail.value });
  },

  onInputCode(e) {
    this.setData({ pairCode: e.detail.value });
  },

  async onConfirmPair() {
    const { pairHost, pairCode } = this.data;
    if (!pairHost) {
      wx.showToast({ title: '请先选择或输入 Mac IP', icon: 'none' });
      return;
    }
    if (!/^\d{4}$/.test(pairCode)) {
      wx.showToast({ title: '配对码必须 4 位数字', icon: 'none' });
      return;
    }
    this.setData({ pairStep: 'pairing', pairError: '' });
    try {
      const resp = await sync.pairWithCode({
        host: pairHost,
        code: pairCode,
        deviceId: app.globalData.deviceId,
        deviceName: this.data.deviceInfo
      });
      this.setData({ pairStep: 'paired', pairHost: resp.hostInfo?.name ? pairHost : pairHost });
      wx.showToast({ title: '配对成功', icon: 'success' });
      this.doSync();
    } catch (e) {
      this.setData({ pairStep: 'error', pairError: e.message || '配对失败' });
    }
  },

  onCancelPair() {
    discovery.stopDiscovery();
    this.setData({ pairStep: 'idle', pairCode: '', pairError: '' });
  },

  onUnpair() {
    sync.unpair();
    this.setData({ pairStep: 'idle', pairHost: '' });
    wx.showToast({ title: '已取消连接', icon: 'none' });
  },

  async doSync() {
    this.setData({ syncState: 'syncing' });
    const result = await sync.syncOnce({
      deviceId: app.globalData.deviceId,
      deviceName: this.data.deviceInfo
    });
    if (result.error) {
      this.setData({ syncState: 'error', lastSyncText: '同步失败：' + result.error });
    } else {
      this.setData({
        syncState: 'synced',
        lastSyncText: `拉取 ${result.pulled} · 推送 ${result.pushed} · 刚刚`
      });
      this.refresh();
    }
  },

  onExport() {
    const records = storage.loadAll().filter(r => !r.deleted);
    const md = records.map(r => {
      const date = new Date(r.createdAt).toLocaleString('zh-CN');
      const amount = r.amount ? ` ¥${r.amount}` : '';
      const tags = r.tags.length ? ' ' + r.tags.map(t => `#${t}`).join(' ') : '';
      return `- [${date}]${amount} ${r.content}${tags}`;
    }).join('\n');

    wx.setClipboardData({
      data: '# 闪记导出\n\n' + md,
      success: () => {
        wx.showToast({ title: '已复制到剪贴板', icon: 'success' });
      }
    });
  }
});
