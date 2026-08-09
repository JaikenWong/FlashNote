import SwiftUI

/// Cmd+N 唤起的快速记录浮层
struct QuickRecordModal: View {
    @ObservedObject var store: RecordStore
    @Binding var isOpen: Bool
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.08)
                .ignoresSafeArea()
                .onTapGesture { close() }

            // 弹窗
            VStack(spacing: 14) {
                inputField
                hintRow
            }
            .padding(20)
            .frame(width: 560)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.greenFaint, lineWidth: 1)
            )
            .onAppear { focused = true }
        }
        .onExitCommand { close() }
    }

    private var inputField: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("午饭 28 #餐 · 想法 #产品")
                    .foregroundColor(Theme.text4)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
            }
            TextEditor(text: $text)
                .font(.system(size: 16))
                .focused($focused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 140)
                .onSubmit { submit() }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.page)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(focused ? Theme.green : Theme.border, lineWidth: focused ? 1.5 : 1)
        )
    }

    private var hintRow: some View {
        HStack(spacing: 8) {
            // 解析预览
            if !text.isEmpty, let preview = RecordParser.parse(text, deviceId: DeviceInfo.deviceId) {
                if let amount = preview.amount {
                    HStack(spacing: 1) {
                        Text("¥")
                        Text(String(format: "%.2f", amount))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.warn)
                }
                if !preview.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(preview.tags.prefix(5), id: \.self) { t in
                            TagChip(name: t)
                        }
                    }
                }
                Text(preview.type == .expense ? "账目" : "笔记")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.text3)
            }
            Spacer()

            HStack(spacing: 4) {
                Text("⌘↵ 保存")
                Text("·")
                Text("esc 关闭")
            }
            .font(.system(size: 11))
            .foregroundColor(Theme.text3)

            Button(action: submit) {
                Text("记录")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.green)
                    )
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
        }
    }

    private func submit() {
        guard !text.isEmpty, let _ = store.addFromInput(text) else { return }
        text = ""
        close()
    }

    private func close() {
        isOpen = false
    }
}
