import SwiftUI
import AppKit

/// 导出浮层：Markdown / CSV
struct ExportModal: View {
    @ObservedObject var store: RecordStore
    @Binding var isOpen: Bool
    @State private var format: Format = .markdown
    @State private var preview: String = ""

    enum Format: String, CaseIterable {
        case markdown = "Markdown"
        case csv      = "CSV"
        case json     = "JSON"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.08).ignoresSafeArea()
                .onTapGesture { isOpen = false }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("导出数据")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button("关闭") { isOpen = false }
                        .buttonStyle(.plain)
                        .foregroundColor(Theme.text3)
                }

                // 格式选择
                HStack(spacing: 6) {
                    ForEach(Format.allCases, id: \.self) { f in
                        Button {
                            format = f
                            refresh()
                        } label: {
                            Text(f.rawValue)
                                .font(.system(size: 12, weight: format == f ? .semibold : .regular))
                                .foregroundColor(format == f ? Theme.greenDeep : Theme.text2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(format == f ? Theme.greenSoft : Color(white: 0.96))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 预览
                ScrollView {
                    Text(preview)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.text1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .textSelection(.enabled)
                }
                .frame(height: 240)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.page)
                )

                HStack {
                    Text("\(count) 条记录")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text3)
                    Spacer()
                    Button {
                        copyToClipboard()
                    } label: {
                        Text("复制到剪贴板")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.border2, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        saveToFile()
                    } label: {
                        Text("保存为文件")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Theme.green)
                            )
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(width: 600)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 8)
            )
        }
        .onAppear { refresh() }
    }

    private var visibleRecords: [Record] {
        store.records.filter { !$0.deleted }.sorted { $0.createdAt > $1.createdAt }
    }

    private var count: Int { visibleRecords.count }

    private func refresh() {
        switch format {
        case .markdown: preview = Exporter.markdown(visibleRecords)
        case .csv:      preview = Exporter.csv(visibleRecords)
        case .json:     preview = Exporter.json(visibleRecords)
        }
    }

    private func copyToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(preview, forType: .string)
    }

    private func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: format == .json ? "json" : format == .csv ? "csv" : "md")].compactMap { $0 }
        panel.nameFieldStringValue = "闪记-导出-\(formattedDate()).\(format == .json ? "json" : format == .csv ? "csv" : "md")"
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                try? preview.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }
}

enum Exporter {
    static func markdown(_ records: [Record]) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        var out = "# 闪记导出\n\n共 \(records.count) 条记录\n\n"
        for r in records {
            let date = f.string(from: r.createdAt)
            let amount = r.amount.map { " ¥\(String(format: "%.2f", $0))" } ?? ""
            let tags = r.tags.isEmpty ? "" : "  " + r.tags.map { "#\($0)" }.joined(separator: " ")
            let type = r.type == .expense ? "💰" : "📝"
            out += "- \(type) `\(date)`\(amount) \(r.content)\(tags)\n"
        }
        return out
    }

    static func csv(_ records: [Record]) -> String {
        var out = "id,type,content,amount,tags,createdAt,deviceId,deleted\n"
        for r in records {
            let row = [
                r.id.uuidString,
                r.type.rawValue,
                csvEscape(r.content),
                r.amount.map { String($0) } ?? "",
                csvEscape(r.tags.joined(separator: "|")),
                ISO8601DateFormatter().string(from: r.createdAt),
                csvEscape(r.deviceId),
                r.deleted ? "1" : "0"
            ]
            out += row.joined(separator: ",") + "\n"
        }
        return out
    }

    static func json(_ records: [Record]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    private static func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}