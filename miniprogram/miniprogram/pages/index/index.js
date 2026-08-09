// pages/index/index.js
const app = getApp();
const { parse } = require('../../utils/parser.js');
const storage = require('../../utils/storage.js');

Page({
  data: {
    records: [],
    groupedRecords: [],
    draft: '',
    showModal: false,
    previewType: '',
    previewAmount: '',
    previewTags: []
  },

  onShow() {
    // 每次显示都重新加载（保证从其他页回来时数据最新）
    this.loadAndGroup();
  },

  loadAndGroup() {
    const records = storage.loadAll().filter(r => !r.deleted);
    this.setData({ records });
    this.setData({ groupedRecords: this.groupByDay(records) });
  },

  groupByDay(records) {
    const sorted = records.slice().sort((a, b) =>
      new Date(b.createdAt) - new Date(a.createdAt)
    );
    const groups = {};
    const order = [];
    for (const r of sorted) {
      const d = new Date(r.createdAt);
      const key = `${d.getFullYear()}年${d.getMonth() + 1}月`;
      if (!groups[key]) {
        groups[key] = { day: key, sum: 0, count: 0, records: [] };
        order.push(key);
      }
      groups[key].records.push(r);
      groups[key].count += 1;
      if (r.amount) groups[key].sum += r.amount;
    }
    return order.map(k => {
      const g = groups[k];
      g.sumText = g.sum > 0 ? `¥${g.sum.toFixed(0)}` : '';
      return g;
    });
  },

  // 底部输入条
  onInput(e) {
    const text = e.detail.value;
    this.setData({ draft: text }, () => this.updatePreview(text));
  },

  updatePreview(text) {
    if (!text.trim()) {
      this.setData({ previewType: '', previewAmount: '', previewTags: [] });
      return;
    }
    const preview = parse(text, app.globalData.deviceId);
    if (preview) {
      this.setData({
        previewType: preview.type,
        previewAmount: preview.amount ? preview.amount.toFixed(2) : '',
        previewTags: preview.tags
      });
    }
  },

  onSubmit() {
    const text = this.data.draft.trim();
    if (!text) return;
    const record = parse(text, app.globalData.deviceId);
    if (record) {
      storage.add(record);
      this.setData({ draft: '' });
      this.updatePreview('');
      this.loadAndGroup();
      wx.showToast({ title: '已记录', icon: 'success', duration: 800 });
    }
  },

  onTapAdd() {
    this.setData({ showModal: true });
  },

  onCloseModal() {
    this.setData({ showModal: false });
  },

  onModalInput(e) {
    const text = e.detail.value;
    this.setData({ draft: text }, () => this.updatePreview(text));
  },

  onModalSubmit() {
    this.onSubmit();
    this.setData({ showModal: false });
  },

  onLongPressCard(e) {
    const id = e.currentTarget.dataset.id;
    wx.showActionSheet({
      itemList: ['删除'],
      success: (res) => {
        if (res.tapIndex === 0) {
          storage.softDelete(id);
          this.loadAndGroup();
          wx.showToast({ title: '已删除', icon: 'none' });
        }
      }
    });
  }
});
