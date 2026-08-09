import SwiftUI

struct CardView: View {
    let record: Record
    var onDelete: () -> Void = {}
    var onEdit: () -> Void = {}
    var onTagClick: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !record.content.isEmpty {
                Text(record.content)
                    .font(.system(size: 14.5))
                    .foregroundColor(Theme.text1)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                if let amount = record.amount {
                    Text(String(format: "¥%.2f", amount))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.warn)
                    Text("·").foregroundColor(Theme.text4)
                }
                ForEach(record.tags, id: \.self) { tag in
                    Button {
                        onTagClick(tag)
                    } label: {
                        TagChip(name: tag)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(relativeTime(record.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.text3)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.rCard)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
        .overlay(alignment: .leading) {
            // 左侧 3px 竖条
            HStack {
                if record.type == .expense {
                    VStack(spacing: 3) {
                        ForEach(0..<8, id: \.self) { _ in
                            Rectangle()
                                .fill(Theme.warn)
                                .frame(width: 3, height: 4)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Theme.green)
                        .frame(width: 3)
                        .cornerRadius(2)
                }
            }
            .padding(.vertical, 12)
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button {
                onTagClick(record.tags.first ?? "")
            } label: {
                Label("筛选第一个标签", systemImage: "tag")
            }
            .disabled(record.tags.isEmpty)
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = Locale(identifier: "zh_CN")
        return f.localizedString(for: date, relativeTo: Date())
    }
}

/// 标签 chip：浅绿底 + 绿字
struct TagChip: View {
    let name: String
    var warm: Bool = false

    var body: some View {
        Text("#\(name)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(warm ? Color(red: 0.83, green: 0.53, blue: 0.00) : Theme.greenDeep)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.rChip)
                    .fill(warm ? Theme.warnSoft : Theme.greenSoft)
            )
    }
}
