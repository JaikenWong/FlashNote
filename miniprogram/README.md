# FlashNote · 微信小程序

M2 MVP。

## 功能（M2 已实现）

- ✅ 全部（首页）：卡片流 + 月份分组 + 实时解析预览
- ✅ 快速记录：底部输入条 + 浮层
- ✅ 一句话解析：金额 / #标签 / 自动归类
- ✅ 统计：月支出 / 分类占比 / 7 天柱状
- ✅ 我的：设备信息 / 配对（mock） / 导出 Markdown
- ✅ 本地存储：`wx.setStorageSync`
- ✅ 长按删除
- ⏳ 局域网同步（M3 启动）

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
    ├── app.js
    ├── app.json
    ├── app.wxss
    ├── sitemap.json
    ├── pages/
    │   ├── index/    # 全部
    │   ├── stats/    # 统计
    │   └── mine/     # 我的
    ├── utils/
    │   ├── parser.js
    │   ├── storage.js
    │   └── device.js
    └── images/       # tabBar 图标
```

## 调试

用微信开发者工具打开 `miniprogram/` 目录即可：

1. 顶部 → 导入项目
2. 目录选 `FlashNote/miniprogram/`
3. AppID 用「测试号」或填自己的
4. 编译运行

## 数据迁移

数据存在微信 storage，AppID 切换 / 缓存清理会丢。后续 M3 同步会通过 Mac 端持久化。
