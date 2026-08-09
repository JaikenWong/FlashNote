import Foundation

/// 4 位配对码生成 + 校验
final class PairCodeManager {
    private(set) var code: String
    private let key = "flashnote.pairCode"

    init() {
        if let existing = UserDefaults.standard.string(forKey: key),
           let _ = Int(existing), existing.count == 4 {
            self.code = existing
        } else {
            self.code = Self.generate()
            persist()
        }
    }

    func regenerate() {
        code = Self.generate()
        persist()
    }

    /// 一次性校验：成功后失效
    func consume(_ input: String) -> Bool {
        let ok = input == code
        if ok { regenerate() }
        return ok
    }

    private static func generate() -> String {
        String(format: "%04d", Int.random(in: 0...9999))
    }

    private func persist() {
        UserDefaults.standard.set(code, forKey: key)
    }
}
