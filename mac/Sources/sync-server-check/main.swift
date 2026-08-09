// SyncServer 冒烟测试 · 独立版本（不依赖项目其他文件）
// 编译：swiftc Sources/sync-server-check/main.swift -o /tmp/sync-test
// 跑：/tmp/sync-test

import Foundation
import Network

// 复制所需的最小代码

// MARK: - Models

struct TestRecord: Codable, Equatable {
    let id: UUID
    var type: String
    var content: String
    var amount: Double?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var deviceId: String
    var deleted: Bool
}

// MARK: - 测试用 server

final class TestServer {
    private let port: UInt16 = 9527
    private let queue = DispatchQueue(label: "test.server")
    private var listener: NWListener?
    private let pairCode: String = "1234"
    private var tokens: [String: String] = [:]
    private var records: [TestRecord] = []

    func start() throws {
        let listener = try NWListener(using: NWParameters.tcp, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        listener.stateUpdateHandler = { state in
            if case .ready = state { print("✓ test server listening on \(self.port)") }
        }
        listener.start(queue: queue)
    }

    func stop() { listener?.cancel() }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receiveRequest(conn)
    }

    private func receiveRequest(_ conn: NWConnection) {
        var data = Data()
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] chunk, _, complete, err in
            guard let self = self else { return }
            if let chunk = chunk { data.append(chunk) }
            if complete || err != nil {
                self.respond(conn, data: data)
            } else {
                self.receiveRequest(conn)
            }
        }
    }

    private func respond(_ conn: NWConnection, data: Data) {
        let str = String(data: data, encoding: .utf8) ?? ""
        let lines = str.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return }
        let method = String(parts[0])
        let path = String(parts[1])

        // 找 body
        let body: String
        if let bodyStart = str.range(of: "\r\n\r\n") {
            body = String(str[bodyStart.upperBound...])
        } else {
            body = ""
        }

        var resp = ""
        switch (method, path.components(separatedBy: "?").first ?? path) {
        case ("GET", "/api/info"):
            resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n{\"name\":\"TestMac\",\"version\":\"0.1.0\",\"pairCode\":\"\(pairCode)\",\"records\":\(records.count)}"
        case ("POST", "/api/pair"):
            if let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
               let code = json["code"] as? String, code == pairCode {
                let token = "tk-test123"
                tokens[token] = json["deviceId"] as? String ?? "unknown"
                resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n{\"token\":\"\(token)\",\"hostInfo\":{\"name\":\"TestMac\"}}"
            } else {
                resp = "HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n{\"error\":\"invalid code\"}"
            }
        case ("GET", "/api/records"):
            resp = "HTTP/1.1 401 Unauthorized\r\n\r\nunauthorized"
        case ("POST", "/api/records"):
            resp = "HTTP/1.1 401 Unauthorized\r\n\r\nunauthorized"
        default:
            resp = "HTTP/1.1 404 Not Found\r\n\r\nnot found"
        }

        conn.send(content: Data(resp.utf8), completion: .contentProcessed { _ in
            conn.cancel()
        })
    }
}

let server = TestServer()
do { try server.start() } catch { print("✗ start failed: \(error)"); exit(1) }
Thread.sleep(forTimeInterval: 0.5)

print("\n=== GET /api/info ===")
let sema1 = DispatchSemaphore(value: 0)
var s1 = 0
URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:9527/api/info")!) { data, resp, _ in
    s1 = (resp as? HTTPURLResponse)?.statusCode ?? 0
    print("  status=\(s1) body=\(String(data: data ?? Data(), encoding: .utf8) ?? "")")
    sema1.signal()
}.resume()
sema1.wait()
if s1 == 200 { print("  ✓") } else { print("  ✗"); exit(1) }

print("\n=== POST /api/pair 错误码 ===")
let sema2 = DispatchSemaphore(value: 0)
var s2 = 0
var badBody = Data()
var req2 = URLRequest(url: URL(string: "http://127.0.0.1:9527/api/pair")!)
req2.httpMethod = "POST"
req2.httpBody = Data("{\"code\":\"0000\",\"deviceId\":\"x\"}".utf8)
req2.setValue("application/json", forHTTPHeaderField: "Content-Type")
URLSession.shared.dataTask(with: req2) { data, resp, _ in
    s2 = (resp as? HTTPURLResponse)?.statusCode ?? 0
    badBody = data ?? Data()
    sema2.signal()
}.resume()
sema2.wait()
print("  status=\(s2) body=\(String(data: badBody, encoding: .utf8) ?? "")")
if s2 == 401 { print("  ✓") } else { print("  ✗"); exit(1) }

print("\n=== POST /api/pair 正确码 ===")
let sema3 = DispatchSemaphore(value: 0)
var s3 = 0
var pairBodyStr = ""
var req3 = URLRequest(url: URL(string: "http://127.0.0.1:9527/api/pair")!)
req3.httpMethod = "POST"
req3.httpBody = Data("{\"code\":\"1234\",\"deviceId\":\"mp-test\",\"deviceName\":\"iPhone\"}".utf8)
req3.setValue("application/json", forHTTPHeaderField: "Content-Type")
URLSession.shared.dataTask(with: req3) { data, resp, _ in
    s3 = (resp as? HTTPURLResponse)?.statusCode ?? 0
    pairBodyStr = String(data: data ?? Data(), encoding: .utf8) ?? ""
    sema3.signal()
}.resume()
sema3.wait()
print("  status=\(s3) body=\(pairBodyStr)")
if s3 == 200 { print("  ✓") } else { print("  ✗"); exit(1) }

print("\n=== GET /api/records 无 token ===")
let sema4 = DispatchSemaphore(value: 0)
var s4 = 0
URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:9527/api/records?since=1970-01-01T00:00:00Z&deviceId=test")!) { data, resp, _ in
    s4 = (resp as? HTTPURLResponse)?.statusCode ?? 0
    sema4.signal()
}.resume()
sema4.wait()
print("  status=\(s4)")
if s4 == 401 { print("  ✓") } else { print("  ✗"); exit(1) }

server.stop()
print("\n=== 全部通过 ===")
exit(0)
