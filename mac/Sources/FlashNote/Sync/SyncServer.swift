import Foundation
import Network

/// 局域网 HTTP server · 端口 9527
/// 路由：
///   GET  /api/info              - 服务端信息
///   POST /api/pair              - 配对
///   GET  /api/records?since=    - 拉取变更
///   POST /api/records           - 推送变更
final class SyncServer {
    private let port: UInt16
    private let queue = DispatchQueue(label: "flashnote.sync.server")
    private var listener: NWListener?
    private let pairManager: PairCodeManager
    private let tokenStore: SyncTokenStore

    /// 在主线程中读取所有记录（快照）
    private let recordsProvider: () -> [Record]
    /// 在主线程中合并远端变更（LWW 已在外层处理完）
    private let recordsApplier: ([Record]) -> Void

    /// 设备拉取 / 推送的回调
    var onRecordsChanged: (() -> Void)?

    init(
        port: UInt16 = 9527,
        pairManager: PairCodeManager,
        tokenStore: SyncTokenStore,
        recordsProvider: @escaping () -> [Record],
        recordsApplier: @escaping ([Record]) -> Void
    ) {
        self.port = port
        self.pairManager = pairManager
        self.tokenStore = tokenStore
        self.recordsProvider = recordsProvider
        self.recordsApplier = recordsApplier
    }

    func start() throws {
        let params = NWParameters.tcp
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let listener = try NWListener(using: params, on: nwPort)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[SyncServer] listening on port \(self.port)")
            case .failed(let err):
                print("[SyncServer] failed: \(err)")
            default: break
            }
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection handling

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receiveRequest(conn)
    }

    /// 用一个 struct 持有 per-connection 状态，避免递归调用时状态丢失
    private final class ConnState {
        var request = SyncRequest()
        var headerBuf = Data()
        var bodyTarget: Int? = nil
        var bodyBuf = Data()
        var done = false
    }

    private func receiveRequest(_ conn: NWConnection) {
        let state = ConnState()
        // 闭包持有 state 引用（class），状态跨 receive 调用保持
        receiveLoop(conn, state: state)
    }

    private func receiveLoop(_ conn: NWConnection, state: ConnState) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if state.done { return }
            if let error = error {
                NSLog("[SyncServer] receive error: %@", String(describing: error))
                conn.cancel()
                return
            }
            if let data = data, !data.isEmpty {
                if state.request.method == nil {
                    state.headerBuf.append(data)
                    if let range = state.headerBuf.range(of: Data("\r\n\r\n".utf8)) {
                        let headerData = state.headerBuf.subdata(in: 0..<range.lowerBound)
                        let rest = state.headerBuf.subdata(in: range.upperBound..<state.headerBuf.count)
                        state.request = Self.parseRequest(headerData) ?? state.request
                        if let cl = state.request.headers["content-length"], let n = Int(cl) {
                            state.bodyTarget = n
                            state.bodyBuf.append(rest)
                        }
                        if state.bodyTarget == nil {
                            state.done = true
                            self.send(conn, self.response(for: state.request))
                            return
                        }
                    }
                } else {
                    state.bodyBuf.append(data)
                }

                if let target = state.bodyTarget, state.bodyBuf.count >= target {
                    state.request.body = state.bodyBuf.prefix(target)
                    state.done = true
                    self.send(conn, self.response(for: state.request))
                    return
                }
            }
            if isComplete {
                if !state.done {
                    conn.cancel()
                }
                return
            }
            self.receiveLoop(conn, state: state)
        }
    }

    private static func parseRequest(_ data: Data) -> SyncRequest? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        let lines = str.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let path = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            if let colon = line.firstIndex(of: ":") {
                let k = line[..<colon].lowercased().trimmingCharacters(in: .whitespaces)
                let v = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[k] = v
            }
        }
        return SyncRequest(method: method, path: path, headers: headers, body: Data())
    }

    // MARK: - Routing

    private func response(for req: SyncRequest) -> SyncResponse {
        let (path, query) = Self.parsePath(req.path)

        switch (req.method, path) {
        case ("GET", "/api/info"):
            return jsonOk([
                "name": Host.current().localizedName ?? "Mac",
                "version": "0.1.0",
                "pairCode": pairManager.code,
                "records": recordsProvider().filter { !$0.deleted }.count
            ])

        case ("POST", "/api/pair"):
            return handlePair(body: req.body)

        case ("GET", "/api/records"):
            guard authorize(req) else { return unauthorized() }
            return handlePull(query: query)

        case ("POST", "/api/records"):
            guard authorize(req) else { return unauthorized() }
            return handlePush(body: req.body)

        case ("GET", "/api/ping"):
            // 轻量 ping，用于 web 端检测 server 可达性
            return jsonOk(["ok": true])

        case ("GET", _):
            // 其它 GET 请求：serve 静态 web 资源
            if req.method == "GET" {
                return serveStatic(path: path)
            }
            return SyncResponse(status: 404, body: Data("not found".utf8))

        default:
            return SyncResponse(status: 404, body: Data("not found".utf8))
        }
    }

    /// Serve 静态 web 资源（index.html / css / js / images / manifest.json / sw.js）
    private func serveStatic(path: String) -> SyncResponse {
        // 规范化路径，防 ../ 越权
        var cleanPath = path
        if cleanPath == "/" { cleanPath = "/index.html" }
        // 去掉前导 /，保留子目录
        let relPath = String(cleanPath.dropFirst())
        if relPath.contains("..") { return SyncResponse(status: 403, body: Data("forbidden".utf8)) }

        // SwiftPM 把 web/ 整个目录拷进了 bundle，资源路径 = "web/<relPath>"
        // 用 path(forResource:ofType:) 拿子目录里的文件
        let parts = relPath.split(separator: ".", maxSplits: 1).map(String.init)
        let name = parts[0]
        let ext = parts.count > 1 ? parts[1] : nil
        let subdir = "web"

        let url: URL?
        if let ext = ext {
            url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdir)
        } else {
            // 无扩展名：直接用 path
            url = Bundle.module.url(forResource: relPath, withExtension: nil, subdirectory: subdir)
        }

        guard let fileURL = url else {
            return SyncResponse(status: 404, body: Data("not found: \(relPath)".utf8))
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return SyncResponse(status: 200, body: data, contentType: Self.mimeType(for: relPath))
        } catch {
            return SyncResponse(status: 500, body: Data("read error".utf8))
        }
    }

    private static func mimeType(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "html": return "text/html; charset=utf-8"
        case "css":  return "text/css; charset=utf-8"
        case "js":   return "application/javascript; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "png":  return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg":  return "image/svg+xml"
        case "ico":  return "image/x-icon"
        case "webmanifest": return "application/manifest+json"
        default:     return "application/octet-stream"
        }
    }

    private func handlePair(body: Data) -> SyncResponse {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let code = json["code"] as? String,
              let deviceId = json["deviceId"] as? String else {
            return jsonErr(400, "bad request")
        }
        guard pairManager.consume(code) else {
            return jsonErr(401, "invalid code")
        }
        let name = (json["deviceName"] as? String) ?? "未知设备"
        let token = tokenStore.issue(deviceId: deviceId, deviceName: name)
        return jsonOk([
            "token": token,
            "hostInfo": [
                "name": Host.current().localizedName ?? "Mac",
                "version": "0.1.0"
            ]
        ])
    }

    private func handlePull(query: [String: String]) -> SyncResponse {
        let since = query["since"].flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(timeIntervalSince1970: 0)
        let deviceId = query["deviceId"] ?? ""
        // 在主线程中读取
        let all = recordsProvider()
        let changes = all.filter { $0.updatedAt > since }

        let arr = changes.map { record -> [String: Any] in
            [
                "id": record.id.uuidString,
                "type": record.type.rawValue,
                "content": record.content,
                "amount": record.amount as Any,
                "tags": record.tags,
                "createdAt": ISO8601DateFormatter().string(from: record.createdAt),
                "updatedAt": ISO8601DateFormatter().string(from: record.updatedAt),
                "deviceId": record.deviceId,
                "deleted": record.deleted
            ]
        }
        _ = deviceId
        return jsonOk([
            "changes": arr,
            "serverTime": ISO8601DateFormatter().string(from: Date())
        ])
    }

    private func handlePush(body: Data) -> SyncResponse {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let changes = json["changes"] as? [[String: Any]] else {
            return jsonErr(400, "bad request")
        }
        var accepted: [String] = []
        var incoming: [Record] = []
        for raw in changes {
            guard let idStr = raw["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let typeStr = raw["type"] as? String,
                  let type = RecordType(rawValue: typeStr) else { continue }
            let content = (raw["content"] as? String) ?? ""
            let amount = raw["amount"] as? Double
            let tags = (raw["tags"] as? [String]) ?? []
            let createdAt = (raw["createdAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
            let updatedAt = (raw["updatedAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
            let deviceId = (raw["deviceId"] as? String) ?? "unknown"
            let deleted = (raw["deleted"] as? Bool) ?? false

            incoming.append(Record(id: id, type: type, content: content, amount: amount, tags: tags,
                                   createdAt: createdAt, updatedAt: updatedAt, deviceId: deviceId, deleted: deleted))
            accepted.append(idStr)
        }
        // 在主线程中应用
        recordsApplier(incoming)
        onRecordsChanged?()

        return jsonOk([
            "accepted": accepted,
            "serverTime": ISO8601DateFormatter().string(from: Date())
        ])
    }

    // MARK: - Helpers

    private func authorize(_ req: SyncRequest) -> Bool {
        guard let auth = req.headers["authorization"],
              auth.hasPrefix("Bearer "),
              tokenStore.lookup(String(auth.dropFirst("Bearer ".count))) != nil else {
            return false
        }
        return true
    }

    private static func parsePath(_ raw: String) -> (String, [String: String]) {
        let parts = raw.split(separator: "?", maxSplits: 1)
        let path = String(parts[0])
        var query: [String: String] = [:]
        if parts.count > 1 {
            for pair in parts[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    query[String(kv[0])] = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                }
            }
        }
        return (path, query)
    }

    private func jsonOk(_ obj: [String: Any]) -> SyncResponse {
        let data = (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])) ?? Data("{}".utf8)
        return SyncResponse(status: 200, body: data, contentType: "application/json; charset=utf-8")
    }

    private func jsonErr(_ code: Int, _ msg: String) -> SyncResponse {
        let data = (try? JSONSerialization.data(withJSONObject: ["error": msg])) ?? Data("{}".utf8)
        return SyncResponse(status: code, body: data, contentType: "application/json; charset=utf-8")
    }

    private func unauthorized() -> SyncResponse {
        jsonErr(401, "unauthorized")
    }

    private func send(_ conn: NWConnection, _ resp: SyncResponse) {
        let body = resp.body
        let headers = [
            "HTTP/1.1 \(resp.status) \(httpStatusText(resp.status))",
            "Content-Type: \(resp.contentType)",
            "Content-Length: \(body.count)",
            "Access-Control-Allow-Origin: *",
            "Cache-Control: no-cache",
            "Connection: close",
            ""
        ].joined(separator: "\r\n")
        var payload = Data(headers.utf8)
        payload.append(contentsOf: Array("\r\n".utf8))
        payload.append(body)

        conn.send(content: payload, completion: .contentProcessed { _ in
            conn.cancel()
        })
    }

    private func httpStatusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "OK"
        }
    }
}

struct SyncRequest {
    var method: String?
    var path: String = ""
    var headers: [String: String] = [:]
    var body: Data = Data()
}

struct SyncResponse {
    let status: Int
    let body: Data
    var contentType: String = "application/json; charset=utf-8"
}
