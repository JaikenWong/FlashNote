# FlashNote · Mac 端

原生 SwiftUI · M1 MVP。

## 功能（M1 已实现）

- ✅ 快速记录（Cmd+N 唤起浮层 / 底部输入条）
- ✅ 一句话解析：自动识别金额、标签、分类
- ✅ 卡片流（按月分组，含月支出小计）
- ✅ 标签 / 分类筛选
- ✅ 全文搜索
- ✅ 本地 JSON 存储（Application Support/FlashNote/records.json）
- ✅ 删除（右键菜单）
- ⏳ 同步（M3 启动）

## 运行

```bash
cd mac
swift run
```

首次启动会生成：
- 设备 ID：保存在 UserDefaults（`flashnote.deviceId`）
- 数据文件：`~/Library/Application Support/FlashNote/records.json`

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
├── Sources/FlashNote/
│   ├── FlashNoteApp.swift       # @main · 菜单 / Cmd+N
│   ├── Models/
│   │   ├── Record.swift
│   │   ├── Category.swift
│   │   └── DeviceInfo.swift
│   ├── Store/
│   │   ├── RecordStore.swift    # 本地存储 + 过滤
│   │   └── Parser.swift
│   ├── Theme/
│   │   └── DesignTokens.swift   # 与 DESIGN.md §6 对齐
│   └── Views/
│       ├── ContentView.swift
│       ├── SidebarView.swift
│       ├── CardListView.swift
│       ├── CardView.swift
│       ├── QuickInputBar.swift
│       └── QuickRecordModal.swift
```

## 后续

- M2：微信小程序 MVP
- M3：局域网同步打通（mDNS + 4 位配对码）
- M4：统计页、搜索增强、导出
