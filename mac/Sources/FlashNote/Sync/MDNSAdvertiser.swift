import Foundation
import Network

/// mDNS 服务广播 · `_flashnote._tcp` on port 9527
/// 小程序用 wx.startLocalServiceDiscovery 监听
final class MDNSAdvertiser {
    private var service: NWListener?
    private let port: UInt16
    private let serviceType = "_flashnote._tcp"

    init(port: UInt16) {
        self.port = port
    }

    func start() throws {
        let params = NWParameters.tcp
        let nwPort = NWEndpoint.Port(rawValue: port)!
        let listener = try NWListener(using: params, on: nwPort)
        self.service = listener

        listener.service = NWListener.Service(type: serviceType)
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[mDNS] broadcasting as \(self.serviceType) on port \(self.port)")
            case .failed(let err):
                print("[mDNS] failed: \(err)")
            default: break
            }
        }
        // 接收连接（响应 client 的查询）
        listener.newConnectionHandler = { conn in
            // 不响应数据，仅保持 mDNS 注册
            conn.start(queue: .global())
            conn.cancel()
        }
        listener.start(queue: .global())
    }

    func stop() {
        service?.cancel()
        service = nil
    }
}
