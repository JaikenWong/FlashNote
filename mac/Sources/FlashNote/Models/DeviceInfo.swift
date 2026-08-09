import Foundation

/// 当前设备的身份信息（M3 同步时用）
enum DeviceInfo {
    /// 稳定的设备 ID，首次启动生成并持久化
    static let deviceId: String = {
        let key = "flashnote.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = "mac-" + UUID().uuidString.prefix(8).lowercased()
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()

    static let displayName: String = {
        Host.current().localizedName ?? "Mac"
    }()
}
