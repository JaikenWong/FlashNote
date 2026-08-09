// utils/device.js
// 设备身份：首次启动生成并持久化（M3 同步用）

function initDevice() {
  let id = wx.getStorageSync('flashnote.deviceId');
  if (!id) {
    id = 'mp-' + Math.random().toString(36).slice(2, 6) + '-' + Math.random().toString(36).slice(2, 6);
    wx.setStorageSync('flashnote.deviceId', id);
  }
  return id;
}

function getDeviceInfo() {
  try {
    const info = wx.getDeviceInfo();
    return {
      model: info.model || '未知设备',
      system: info.system || '',
      platform: info.platform || ''
    };
  } catch (e) {
    return { model: '微信小程序', system: '', platform: '' };
  }
}

module.exports = { initDevice, getDeviceInfo };
