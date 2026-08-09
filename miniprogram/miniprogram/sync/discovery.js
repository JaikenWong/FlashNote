// utils/discovery.js
// 局域网发现：优先用 wx.startLocalServiceDiscovery，失败回退到用户输入 IP
// 注意：mDNS / Bonjour 在小程序里叫 "local service discovery"
// serviceType 跟 Mac 端的 NSNetService 注册保持一致：_flashnote._tcp

const SERVICE_TYPE = '_flashnote._tcp';

let discovering = false;
let discovered = [];

function startDiscovery() {
  return new Promise((resolve, reject) => {
    if (discovering) {
      resolve(discovered);
      return;
    }
    discovered = [];
    wx.startLocalServiceDiscovery({
      serviceType: SERVICE_TYPE,
      success: () => {
        discovering = true;
        // 监听发现事件
        wx.onLocalServiceFound((res) => {
          // res.serviceName / res.ip / res.port
          if (res.ip && !discovered.find(d => d.ip === res.ip)) {
            discovered.push({ name: res.serviceName, ip: res.ip, port: res.port || 9527 });
          }
        });
        // 给浏览器/设备 1-2s 时间响应
        setTimeout(() => resolve(discovered.slice()), 1500);
      },
      fail: (err) => {
        console.warn('[discovery] 失败：', err);
        reject(err);
      }
    });
  });
}

function stopDiscovery() {
  if (discovering) {
    wx.stopLocalServiceDiscovery({
      serviceType: SERVICE_TYPE,
      success: () => { discovering = false; }
    });
  }
}

module.exports = { startDiscovery, stopDiscovery, SERVICE_TYPE };
