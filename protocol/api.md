# FlashNote 同步协议 v1

局域网 HTTP · JSON · 不加密（数据本就在本地）

## 角色

- **Host**（Mac 端）：HTTP server，端口 9527，mDNS 服务 `_flashnote._tcp`
- **Client**（小程序）：发起配对、拉取、上传

## 配对

```
POST /api/pair
Body: { "code": "1234", "deviceId": "mp-xxx", "deviceName": "iPhone 闪记" }
→ 200 { "token": "tk-...", "hostInfo": { "name": "MacBook Pro", "version": "0.1.0" } }
→ 401 { "error": "invalid_code" }
```

后续所有请求带 `Authorization: Bearer <token>`。

## 拉取变更

```
GET /api/records?since=<iso8601>&deviceId=<mp-xxx>
→ 200 {
    "changes": [
      { "id": "r-xxx", "type": "expense", "content": "午饭", "amount": 28,
        "tags": ["餐"], "createdAt": "...", "updatedAt": "...", "deviceId": "mac-xxx", "deleted": false },
      ...
    ],
    "serverTime": "2026-08-09T..."
  }
```

## 推送变更

```
POST /api/records
Headers: Authorization: Bearer <token>
Body: {
  "deviceId": "mp-xxx",
  "changes": [ { "id": "r-yyy", ... } ]
}
→ 200 {
    "accepted": ["r-yyy", ...],   // 服务端成功接收（写入或覆盖）
    "serverTime": "..."
  }
```

## 冲突解决

- 每条记录有 `id`（创建时生成，跨设备保持）+ `updatedAt`
- 接收端对同 `id` 的记录：以 `updatedAt` 较新者为准（LWW）
- 软删除：`deleted: true`，30 天后由 Host 清理

## 发现

- Mac 用 `NSNetService` 注册 `_flashnote._tcp` on port 9527
- 小程序用 `wx.startLocalServiceDiscovery({...})` 监听
- Fallback：用户手动输入 Mac IP（host info 也通过 `/api/info` 暴露）

## 心跳 / 状态

```
GET /api/info
→ 200 { "name": "MacBook Pro", "version": "0.1.0", "pairCode": "1234", "records": 128 }
```
