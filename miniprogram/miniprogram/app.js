// app.js
const { initDevice } = require('./utils/device.js');
const { loadAll } = require('./utils/storage.js');

App({
  globalData: {
    deviceId: '',
    deviceName: '微信小程序',
    records: []
  },

  onLaunch() {
    // 初始化设备信息
    this.globalData.deviceId = initDevice();
    // 加载本地数据
    this.globalData.records = loadAll();
    console.log('[闪记] 启动 · deviceId =', this.globalData.deviceId);
  }
});
