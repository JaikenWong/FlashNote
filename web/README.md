# FlashNote · Web 端

Mobile-first 单页应用，零依赖。**任何设备浏览器打开 Mac 端地址就能用**。

![Web 列表](../docs/screenshots/web-list.png)

## 角色

- 任意浏览器（iPhone Safari / iPad / 桌面 Chrome / 任何）的视图层
- localStorage 做本地缓存
- 通过 HTTP 跟 Mac 端 (`http://<mac-ip>:9527/`) 同步
- PWA：可「加到主屏」当独立 app 用

**Mac 是数据源**。Web 端是 remote UI，localStorage 只是缓存和离线兜底。

## 功能

| 功能 | 状态 | 备注 |
| --- | --- | --- |
| 记录 / 统计 双 tab | ✅ | 顶栏 segmented control |
| 一句话输入 | ✅ | 底部 fixed 输入条 + 实时解析预览 |
| 卡片流（按月分组） | ✅ | 含月支出小计 |
| 搜索 | ✅ | content / #tag / 金额模糊匹配 |
| 标签筛选 | ✅ | 点卡片上 `#tag` 自动填搜索框 |
| 编辑卡片 | ✅ | 点卡片 → 底部 sheet → 实时解析预览 |
| 长按删除 | ✅ | 800ms 进度条 +「松手删除」 |
| 离线队列 | ✅ | offline 事件 + 联网自动重发 |
| 同步状态 pill | ✅ | 绿=已同步 / 橙=同步中 / 红=错误 / 黄=离线 |
| PWA 安装 | ✅ | manifest.json + service worker |

## 同步机制

1. **首次访问** → 弹配对浮层 → 输 Mac 顶栏 4 位码 → POST `/api/pair` → token 存 localStorage
2. **拉取**：GET `/api/records?since=<serverTime>&deviceId=<x>` 用服务端时钟游标
3. **推送**：POST `/api/records` 推本设备所有非删除记录，Mac LWW 判重
4. **触发点**：
   - 新增/编辑/删除 → 自动 sync
   - 页面加载 → bootstrap 拉一次
   - `online` 事件 → 自动重试
   - 手动：点顶栏 pill

## 开发

```bash
# web/ 改完直接刷新浏览器即可
# 但 Mac app build 进 bundle 的 web/ 不会自动更新
# 改 web/ 后必须同步 + 重新 build Mac：
rm -rf mac/Sources/FlashNote/Resources/web
cp -r web/ mac/Sources/FlashNote/Resources/web/
cd mac && swift build
```

或者**临时调试**：直接用浏览器开 `http://localhost:9527/`，Mac app 跑着就生效。

## 目录

```
web/
├── index.html              # 入口：顶栏 / 搜索 / 列表 / quick input
├── manifest.json           # PWA manifest
├── sw.js                   # service worker（network-first，避免缓存老代码）
├── css/
│   └── app.css             # 设计令牌 + 全部样式
├── js/
│   ├── parser.js           # 一句话解析（与 mac/Parser.swift 算法对齐）
│   ├── storage.js          # localStorage 包装 + 同步游标
│   ├── sync.js             # 拉取/推送/合并
│   ├── stats.js            # 统计计算 + 渲染
│   └── app.js              # 主控制器：渲染、事件、tab 切换、编辑 modal
└── images/
    └── icon-512.png
```

## 设计令牌（与 mac/Theme/DesignTokens.swift 对齐）

```css
--c-green:      #52C41A  /* 主色 */
--c-green-soft: #F6FFED  /* 标签底色 */
--c-green-deep: #389E0D  /* hover/pressed */
--c-warn:       #FAAD14
--c-page:       #FAFAFA
--c-text-1:     #1F1F1F
--c-text-2:     #595959
--c-text-3:     #8C8C8C
--c-border:     #F0F0F0

--r-card: 12px
--r-btn:  8px
--r-chip: 6px
```

## 关键决策

- **零框架**：原生 ES6 modules + CSS。包大小 ~12KB（gzip），首屏 < 100ms
- **mobile-first**：viewport 480px 起，断点宽松
- **no-confirm 长按删除**：移动端 confirm() 体验差，800ms 进度条更顺手
- **离线不阻塞**：navigator.onLine 决定是否触发 sync；records 一直在 localStorage，联网就发
- **service worker network-first**：避免缓存老代码导致 fix 不生效（教训）
- **id 用 crypto.randomUUID()**：与 Mac 端 `UUID` 类型严格匹配
- **pull 游标用服务端时钟**：避免本地时钟偏差漏拉
- **softDelete 所有权转移**：web 删 Mac 来的记录时 deviceId 改成本设备，保证推得回去
