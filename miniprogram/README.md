# FlashNote · 微信小程序

M2 MVP + M3 局域网同步客户端。

## 功能

- ✅ 全部（首页）：卡片流 + 月份分组 + 实时解析预览
- ✅ 快速记录：底部输入条 + 浮层
- ✅ 一句话解析：金额 / #标签 / 自动归类
- ✅ 统计：月支出 / 分类占比 / 7 天柱状
- ✅ 我的：设备信息 / 配对 / 同步 / 导出 Markdown
- ✅ 本地存储：`wx.setStorageSync`
- ✅ 长按删除
- ✅ **M3 局域网同步**：mDNS 发现 + 4 位配对码 + HTTP 增量同步 + LWW 合并

## 同步流程

1. Mac 端启动 → mDNS 注册 `_flashnote._tcp` + HTTP server on 9527
2. 小程序进入「我的」→ 开始配对 → mDNS 扫描发现 Mac
3. 选 host + 输入 Mac 端显示的 4 位配对码 → 拿到 token
4. 进入 mine 页面时自动 syncOnce：
   - 拉取 `since=本地最新 updatedAt` 的所有变更
   - LWW 合并到本地
   - 推送本地比 server 新的记录
5. 显示「拉取 N · 推送 M · 刚刚」

## 解析规则

与 Mac 端 `Parser.swift` 完全一致：

输入 `午饭 拉面 28 #餐 #工作日`：

| 部分 | 规则 | 解析结果 |
| --- | --- | --- |
| 金额 | `¥28` / `28元` / `28` | 28.0 |
| 标签 | `#xxx`（中英文/数字/下划线） | `["餐", "工作日"]` |
| 剩余 | — | "午饭 拉面" |
| 类型 | 有金额 → expense，否则 → note | expense |

## 目录

```
miniprogram/
├── project.config.json
└── miniprogram/
    ├── app.js / app.json / app.wxss
    ├── sitemap.json
    ├── pages/
    │   ├── index/    # 全部
    │   ├── stats/    # 统计
    │   └── mine/     # 我的（含配对 UI）
    ├── utils/
    │   ├── parser.js
    │   ├── storage.js
    │   └── device.js
    ├── sync/
    │   ├── discovery.js    # mDNS 扫描
    │   ├── sync-client.js  # HTTP 客户端
    │   └── coordinator.js  # 同步协调（LWW）
    └── images/             # tabBar 图标
```

## 调试

1. Mac 端先 `swift run`（监听 9527）
2. 用微信开发者工具打开 `miniprogram/`
3. 进入「我的」→「开始配对」
4. 输 Mac 端显示的 4 位配对码

> 注：mDNS 发现依赖局域网互通。Mac 端首次需允许网络权限。

## 同步协议

详见 `../protocol/api.md`。
