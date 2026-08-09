// pages/mine/mine.js
const app = getApp();
const storage = require('../../utils/storage.js');
const { getDeviceInfo } = require('../../utils/device.js');

Page({
  data: {
    deviceId: '',
    deviceInfo: '',
    recordCount: 0,
    pairCode: '',
    paired: false
  },

  onShow() {
    this.refresh();
  },

  refresh() {
    const records = storage.loadAll().filter(r => !r.deleted);
    const info = getDeviceInfo();
    this.setData({
      deviceId: app.globalData.deviceId,
      deviceInfo: info.model || '微信小程序',
      recordCount: records.length
    });
  },

  // 模拟：点击"设备配对"生成 4 位码（M3 实装扫描/连接）
  onPair() {
    if (this.data.paired) {
      wx.showToast({ title: '已连接 MacBook Pro', icon: 'none' });
      return;
    }
    const code = String(Math.floor(1000 + Math.random() * 9000));
    this.setData({ pairCode: code, paired: true });
    wx.showToast({ title: `配对码 ${code}`, icon: 'none' });
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
