import Foundation

/// 一条记录：可以是纯笔记，也可以带金额
struct Record: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var type: RecordType
    var content: String
    var amount: Double?          // 仅 expense
    var tags: [String]           // 自动从 #xxx 提取
    var createdAt: Date
    var updatedAt: Date
    var deviceId: String         // 哪台设备创建的（M3 同步用）
    var deleted: Bool = false    // 软删除

    init(
        id: UUID = UUID(),
        type: RecordType,
        content: String,
        amount: Double? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deviceId: String,
        deleted: Bool = false
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.amount = amount
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deviceId = deviceId
        self.deleted = deleted
    }
}

enum RecordType: String, Codable, CaseIterable {
    case note
    case expense
}
