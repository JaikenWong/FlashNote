import Foundation

/// 把用户输入的纯文本解析成 Record。
/// 例：
///   "午饭 拉面 28 #餐 #工作日" → expense, amount=28, tags=[餐,工作日], content="午饭 拉面"
///   "今天听了场关于 local-first 的播客 #想法" → note, tags=[想法]
enum RecordParser {
    /// 主入口：解析一行输入
    static func parse(_ input: String, deviceId: String) -> Record? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var text = trimmed
        var amount: Double? = nil
        var tags: [String] = []

        // 1. 抽金额：¥28 / 28元 / 28
        if let (cleaned, value) = extractAmount(from: text) {
            text = cleaned
            amount = value
        }

        // 2. 抽标签：#xxx（支持中英文/数字/下划线）
        let (cleanedText, extractedTags) = extractTags(from: text)
        text = cleanedText
        tags = extractedTags

        // 3. 剩余文本作为 content（去掉多余空白）
        let content = collapseWhitespace(text)

        // 4. 有金额就是 expense，否则 note
        let type: RecordType = (amount != nil) ? .expense : .note

        return Record(
            type: type,
            content: content,
            amount: amount,
            tags: tags,
            deviceId: deviceId
        )
    }

    // MARK: - 金额抽取

    private static let amountPatterns: [NSRegularExpression] = {
        let patterns = [
            #"¥\s*(\d+(?:\.\d+)?)"#,    // ¥28 / ¥ 28.5
            #"￥\s*(\d+(?:\.\d+)?)"#,    // ￥28
            #"(\d+(?:\.\d+)?)\s*元"#,     // 28元 / 28.5 元
            #"\b(\d+(?:\.\d+)?)\b"#      // 纯数字 28
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static func extractAmount(from text: String) -> (String, Double)? {
        let range = NSRange(text.startIndex..., in: text)
        for regex in amountPatterns {
            if let match = regex.firstMatch(in: text, range: range),
               match.numberOfRanges > 1,
               let valueRange = Range(match.range(at: 1), in: text),
               let value = Double(text[valueRange]) {
                var cleaned = text
                if let fullMatchRange = Range(match.range, in: text) {
                    cleaned.removeSubrange(fullMatchRange)
                }
                return (cleaned, value)
            }
        }
        return nil
    }

    // MARK: - 标签抽取

    private static let tagRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"#([\p{L}\p{N}_]+)"#)
    }()

    private static func extractTags(from text: String) -> (String, [String]) {
        let range = NSRange(text.startIndex..., in: text)
        let matches = tagRegex.matches(in: text, range: range)

        var tags: [String] = []
        var cleaned = text

        // 从后往前删，避免 index shift
        for match in matches.reversed() {
            if match.numberOfRanges > 1,
               let tagRange = Range(match.range(at: 1), in: cleaned) {
                let tag = String(cleaned[tagRange])
                if !tags.contains(tag) {
                    tags.insert(tag, at: 0)  // 保留用户书写顺序
                }
            }
            if let fullRange = Range(match.range, in: cleaned) {
                cleaned.removeSubrange(fullRange)
            }
        }

        return (cleaned, tags)
    }

    // MARK: - 工具

    private static func collapseWhitespace(_ s: String) -> String {
        let comps = s.split(whereSeparator: { $0.isWhitespace })
        return comps.joined(separator: " ")
    }
}
