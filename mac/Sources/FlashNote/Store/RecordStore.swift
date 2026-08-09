import Foundation
import SwiftUI
import Combine

/// 本地数据存储 + 状态管理
/// M1：纯本地 JSON 存储；M3 会叠加同步层
///
/// 注意：不在 @MainActor 上 —— sync server 的后台线程需要直接访问 records。
/// 写操作由 SwiftUI 在主线程触发（@Published 天然保证），后台线程只读。
final class RecordStore: ObservableObject {
    @Published private(set) var records: [Record] = []
    @Published var filter: Filter = .all
    @Published var searchText: String = ""

    private let storeURL: URL
    private let saveQueue = DispatchQueue(label: "flashnote.save", qos: .utility)

    enum Filter: Equatable, Hashable {
        case all
        case note
        case expense
        case tag(String)
    }

    init() {
        self.storeURL = Self.makeStoreURL()
        load()
    }

    // MARK: - 公开 API

    func add(_ record: Record) {
        records.insert(record, at: 0)
        save()
    }

    func addFromInput(_ input: String) -> Record? {
        guard let record = RecordParser.parse(input, deviceId: DeviceInfo.deviceId) else {
            return nil
        }
        add(record)
        return record
    }

    func delete(_ record: Record) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx].deleted = true
            records[idx].updatedAt = Date()
            save()
        }
    }

    func hardDelete(_ record: Record) {
        records.removeAll { $0.id == record.id }
        save()
    }

    /// 远端同步过来的记录合并：LWW
    func mergeFromRemote(_ incoming: [Record]) {
        var changed = false
        for r in incoming {
            if let idx = records.firstIndex(where: { $0.id == r.id }) {
                if r.updatedAt > records[idx].updatedAt {
                    records[idx] = r
                    changed = true
                }
            } else {
                records.append(r)
                changed = true
            }
        }
        if changed { save() }
    }

    /// 本地编辑：替换一条记录
    func replace(_ old: Record, with new: Record) {
        if let idx = records.firstIndex(where: { $0.id == old.id }) {
            records[idx] = new
            save()
        }
    }

    // MARK: - 过滤 / 查询

    var visibleRecords: [Record] {
        var rs = records.filter { !$0.deleted }

        switch filter {
        case .all:     break
        case .note:    rs = rs.filter { $0.type == .note }
        case .expense: rs = rs.filter { $0.type == .expense }
        case .tag(let t): rs = rs.filter { $0.tags.contains(t) }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            rs = rs.filter {
                $0.content.lowercased().contains(q) ||
                $0.tags.contains(where: { $0.lowercased().contains(q) })
            }
        }

        return rs.sorted { $0.createdAt > $1.createdAt }
    }

    /// 全部标签 + 出现次数
    var allTags: [(String, Int)] {
        var counts: [String: Int] = [:]
        for r in records where !r.deleted {
            for t in r.tags { counts[t, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }
    }

    // MARK: - 存储

    private static func makeStoreURL() -> URL {
        let fm = FileManager.default
        let base = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = (base ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("FlashNote", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("records.json")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        do {
            let data = try Data(contentsOf: storeURL)
            self.records = try JSONDecoder.flashnote.decode([Record].self, from: data)
        } catch {
            print("[FlashNote] load failed: \(error)")
        }
    }

    private func save() {
        let snapshot = records
        let url = storeURL
        saveQueue.async {
            do {
                let data = try JSONEncoder.flashnote.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                print("[FlashNote] save failed: \(error)")
            }
        }
    }
}

extension JSONEncoder {
    static let flashnote: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        // 自定义 ISO8601 编码：带 fractional seconds，与 web 端 new Date().toISOString() 一致
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(ISO8601DateFormatter.withFractional.string(from: date))
        }
        return e
    }()
}

extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

extension JSONDecoder {
    static let flashnote: JSONDecoder = {
        let d = JSONDecoder()
        // 跟 Encoder 用同一种 formatter，保证对称
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            // 尝试带 fractional，不带再 fallback
            if let date = ISO8601DateFormatter.withFractional.date(from: s) { return date }
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid ISO date: \(s)")
        }
        return d
    }()
}
