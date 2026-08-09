# FlashNote · Mac 端

原生 SwiftUI 单窗口 app。**数据源 + HTTP server + 静态文件服务**三合一。

## 角色

- **数据源**：所有记录写在本地 `records.json`（`~/Library/Application Support/FlashNote/records.json`）
- **HTTP server**：NWListener 监听 `:9527`，提供同步 API + 静态 web 文件
- **mDNS**：Bonjour 广播 `_flashnote._tcp`，让局域网设备能发现
- **Web 托管**：内置同端口 serve `web/` 目录，浏览器开 `http://<mac-ip>:9527/` 就能用

## 功能

### 记录 & 浏览
- ✅ 快速记录（Cmd+N 唤起浮层 / 底部输入条）
- ✅ 一句话解析：自动识别金额、#标签
- ✅ 卡片流（按月分组 + 月支出小计）
- ✅ 侧边栏：全部 / 笔记 / 账目 / 标签筛选
- ✅ 全文搜索
- ✅ 编辑记录（点卡片）
- ✅ 删除（右键菜单 / 浮层删除按钮）

### 统计 & 导出
- ✅ 统计页：本月支出 / 同比上月 / 分类占比（donut）/ 最近 7 天 / 热门标签
- ✅ 导出：Markdown / CSV / JSON

### 同步（v2 强化）
- ✅ HTTP server + 4 位配对码（一次性，配对后自动 rotate）
- ✅ mDNS 广播（`_flashnote._tcp`）
- ✅ Bearer token 持久化
- ✅ LWW 合并（按 `updatedAt`）
- ✅ 主线程保护（防后台线程并发访问 `@Published`）
- ✅ handlePull 双向闭区间 `since < updatedAt <= now`
- ✅ 静态文件同端口 serve（API + Web 共用 9527）

## 运行

```bash
cd mac
swift run
```

启动后：
- SwiftUI 窗口标题「闪记」，顶栏显示当前 4 位配对码
- HTTP server listening on `:9527`
- mDNS 注册 `_flashnote._tcp`

第一次访问 `http://<mac-ip>:9527/` 的浏览器会看到配对浮层；输 4 位码后建立 token 持久在 localStorage。

## 持久化

| 数据 | 位置 |
| --- | --- |
| 记录 | `~/Library/Application Support/FlashNote/records.json` |
| 设备 ID | UserDefaults `flashnote.deviceId` |
| 配对码 | UserDefaults `flashnote.pairCode` |
| 设备 token | UserDefaults `flashnote.tokens.<deviceId>` |

## 同步协议

详见 [`../protocol/api.md`](../protocol/api.md)。

| 端点 | 用途 |
| --- | --- |
| `GET  /api/info` | 服务端信息（无需认证） |
| `POST /api/pair` | 4 位配对码换取 token |
| `GET  /api/records?since=&deviceId=` | 拉取变更（需 Bearer） |
| `POST /api/records` | 推送变更（需 Bearer） |
| `GET  /api/ping` | 轻量 ping |
| `GET  /<path>` | 静态 web 资源 |

**冲突解决**：LWW（Last Write Wins），按 `updatedAt` 较新者为准。

## 一句话解析规则

输入 `午饭 拉面 28 #餐 #工作日`：

| 部分 | 匹配规则 | 解析结果 |
| --- | --- | --- |
| 金额 | `¥28` / `28元` / `28` | 28.0 |
| 标签 | `#xxx` | `["餐", "工作日"]` |
| 剩余文本 | — | "午饭 拉面" |
| 类型推断 | 有金额 → 账目，否则 → 笔记 | expense |

## 目录

```
mac/
├── Package.swift
├── Tests/FlashNoteTests/
│   └── RecordParserTests.swift
├── SmokeTest/main.swift     # 解析冒烟测试
└── Sources/FlashNote/
    ├── FlashNoteApp.swift           # @main · 菜单 / Cmd+N
    ├── Resources/                   # 图标 + 静态 web（build 时从 ../web 复制）
    │   ├── icon-1024.png
    │   └── web/                     # 与根目录 web/ 保持一致
    ├── Models/
    │   ├── Record.swift             # @Published 记录模型
    │   ├── Category.swift
    │   └── DeviceInfo.swift
    ├── Store/
    │   ├── RecordStore.swift        # 本地存储 + 过滤 + LWW merge
    │   ├── Parser.swift             # 一句话解析
    │   └── StatisticsStore.swift    # 统计计算
    ├── Sync/                        # v2 强化
    │   ├── SyncServer.swift         # HTTP server (NWListener) + 静态 serve
    │   ├── SyncCoordinator.swift    # 主线程保护
    │   ├── MDNSAdvertiser.swift     # Bonjour 广播
    │   ├── PairCodeManager.swift    # 一次性配对码
    │   └── SyncTokenStore.swift     # Bearer token
    ├── Theme/DesignTokens.swift
    └── Views/
        ├── ContentView.swift
        ├── SidebarView.swift
        ├── CardListView.swift
        ├── CardView.swift
        ├── QuickInputBar.swift
        ├── QuickRecordModal.swift
        ├── ExportModal.swift
        └── StatsView.swift
```

## v2 之前 vs 现在

- v1：Mac app 是数据源，小程序是客户端
- **v2**：Mac app 仍是数据源，**Web 端是客户端**（砍掉小程序，Mac 同时托管 web 静态文件）

## 后续（v2 已完成）

- ✅ 局域网同步打通
- ✅ Web 端替换小程序
- ✅ 编辑功能（Mac 端 + Web 端）
- ✅ 统计页（Mac 端 + Web 端）
- ✅ 离线队列（Web 端）
- ✅ 搜索 + 标签筛选（Web 端）
- ✅ 长按删除（Web 端）
