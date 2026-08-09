# FlashNote · Mac 端

原生 SwiftUI · M1 MVP + M3 局域网同步。

## 功能

- ✅ 快速记录（Cmd+N 唤起浮层 / 底部输入条）
- ✅ 一句话解析：自动识别金额、标签、分类
- ✅ 卡片流（按月分组，含月支出小计）
- ✅ 标签 / 分类筛选
- ✅ 全文搜索
- ✅ 本地 JSON 存储（Application Support/FlashNote/records.json）
- ✅ 删除（右键菜单）
- ✅ **M3 局域网同步**：mDNS 注册 + HTTP server on 9527 + 4 位配对码

## 运行

```bash
cd mac
swift run
```

首次启动会生成：
- 设备 ID：保存在 UserDefaults（`flashnote.deviceId`）
- 配对码：保存在 UserDefaults（`flashnote.pairCode`），每次配对后自动 rotate
- 数据文件：`~/Library/Application Support/FlashNote/records.json`

## 同步协议

详见 `../protocol/api.md`。

- 端点：`/api/info`、`/api/pair`、`/api/records` (GET/POST)
- 端口：9527
- mDNS 服务类型：`_flashnote._tcp`
- 冲突：LWW（按 `updatedAt`）

## 解析规则

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
└── Sources/FlashNote/
    ├── FlashNoteApp.swift       # @main · 菜单 / Cmd+N
    ├── Models/
    │   ├── Record.swift
    │   ├── Category.swift
    │   └── DeviceInfo.swift
    ├── Store/
    │   ├── RecordStore.swift    # 本地存储 + 过滤 + 远端合并
    │   └── Parser.swift
    ├── Sync/                    # M3 新增
    │   ├── SyncServer.swift     # HTTP server (NWListener)
    │   ├── MDNSAdvertiser.swift # Bonjour 广播
    │   ├── SyncCoordinator.swift
    │   ├── PairCodeManager.swift
    │   └── SyncTokenStore.swift
    ├── Theme/
    │   └── DesignTokens.swift
    └── Views/
        ├── ContentView.swift
        ├── SidebarView.swift
        ├── CardListView.swift
        ├── CardView.swift
        ├── QuickInputBar.swift
        └── QuickRecordModal.swift
```

## 后续

- M4：统计页、搜索增强、导出
- M5：打磨、发布
