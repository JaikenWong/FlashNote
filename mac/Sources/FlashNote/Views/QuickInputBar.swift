import SwiftUI

/// 主视图底部的快速输入条
struct QuickInputBar: View {
    @ObservedObject var store: RecordStore
    @FocusState private var focused: Bool
    @State private var text: String = ""

    var onSubmit: (Record) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 解析预览
            if !text.isEmpty, let preview = RecordParser.parse(text, deviceId: DeviceInfo.deviceId) {
                ParsePreview(record: preview)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 10) {
                TextField("记一笔… 支持 #标签  ¥金额", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($focused)
                    .onSubmit(handleSubmit)

                if !text.isEmpty {
                    Button(action: handleSubmit) {
                        Text("记录")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Theme.green)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.rCard)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.rCard)
                            .stroke(focused ? Theme.green : Theme.border, lineWidth: focused ? 1.5 : 1)
                    )
                    .shadow(color: focused ? Theme.green.opacity(0.12) : Color.black.opacity(0.04), radius: focused ? 8 : 2, x: 0, y: focused ? 4 : 1)
            )
        }
    }

    private func handleSubmit() {
        let input = text
        guard !input.isEmpty, let record = store.addFromInput(input) else { return }
        text = ""
        onSubmit(record)
    }
}

/// 实时解析预览
struct ParsePreview: View {
    let record: Record

    var body: some View {
        HStack(spacing: 8) {
            if let amount = record.amount {
                HStack(spacing: 2) {
                    Text("¥")
                    Text(String(format: "%.2f", amount))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.warn)
            }
            if !record.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(record.tags.prefix(4), id: \.self) { tag in
                        TagChip(name: tag)
                    }
                }
            }
            Spacer()
            Text(record.type == .expense ? "账目" : "笔记")
                .font(.system(size: 10))
                .foregroundColor(Theme.text3)
        }
        .padding(.horizontal, 4)
    }
}
