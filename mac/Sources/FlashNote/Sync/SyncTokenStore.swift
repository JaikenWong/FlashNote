import Foundation

/// 同步 token 管理：给每个配对设备签发一个 token，用于后续请求认证
final class SyncTokenStore {
    struct Entry: Codable {
        let token: String
        let deviceId: String
        let deviceName: String
        let createdAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let key = "flashnote.syncTokens"

    init() { load() }

    func issue(deviceId: String, deviceName: String) -> String {
        let token = "tk-" + UUID().uuidString.prefix(12).lowercased()
        entries[token] = Entry(token: token, deviceId: deviceId, deviceName: deviceName, createdAt: Date())
        persist()
        return token
    }

    func lookup(_ token: String) -> Entry? {
        entries[token]
    }

    func revoke(_ token: String) {
        entries.removeValue(forKey: token)
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder.flashnote.decode([String: Entry].self, from: data) {
            self.entries = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder.flashnote.encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
