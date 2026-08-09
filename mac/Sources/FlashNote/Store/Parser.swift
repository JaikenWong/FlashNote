import Foundation

/// 把用户输入的纯文本解析成 Record。
/// 例：
///   "午饭 拉面 28 #餐 #工作日" → expense, amount=28, tags=[餐,工作日], content="午饭 拉面"
///   "今天听了场关于 local-first 的播客 #想法" → note, tags=[想法]
///   "昨天晚饭 65 #餐" → expense, amount=65, tags=[餐], content="晚饭", date=昨天
enum RecordParser {
    /// 主入口：解析一行输入
    static func parse(_ input: String, deviceId: String) -> Record? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var text = trimmed
        var amount: Double? = nil
        var tags: [String] = []
        let now = Date()

        // 1. 抽日期（先于金额；否则「3」「8」「2026」会被当 amount 抓走）
        var createdAt = now
        if let (cleaned, date) = extractDate(from: text, now: now) {
            text = cleaned
            createdAt = date
        }

        // 2. 抽金额：¥28 / 28元 / 28
        if let (cleaned, value) = extractAmount(from: text) {
            text = cleaned
            amount = value
        }

        // 3. 抽标签：#xxx（支持中英文/数字/下划线）
        let (cleanedText, extractedTags) = extractTags(from: text)
        text = cleanedText
        tags = extractedTags

        // 4. 剩余文本作为 content（去掉多余空白）
        let content = collapseWhitespace(text)

        // 5. 有金额就是 expense，否则 note
        let type: RecordType = (amount != nil) ? .expense : .note

        return Record(
            type: type,
            content: content,
            amount: amount,
            tags: tags,
            createdAt: createdAt,
            deviceId: deviceId
        )
    }

    // MARK: - 日期抽取

    private static let wdMap: [Character: Int] = [
        "日": 0, "天": 0, "末": 6, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6
    ]
    private static let cnNum: [Character: Int] = [
        "一": 1, "二": 2, "三": 3, "四": 4, "五": 5
    ]

    private static let datePatterns: [(NSRegularExpression, (NSTextCheckingResult?, String, Date) -> Date?)] = {
        var ps: [(NSRegularExpression, (NSTextCheckingResult?, String, Date) -> Date?)] = []

        // 今[天早晚]
        if let r = try? NSRegularExpression(pattern: #"今[天早晚]"#) {
            ps.append((r, { _, _, _ in Date() }))
        }
        // 昨[天晚]
        if let r = try? NSRegularExpression(pattern: #"昨[天晚]"#) {
            ps.append((r, { _, _, now in
                let cal = Calendar.current
                return cal.date(byAdding: .day, value: -1, to: now) ?? now
            }))
        }
        // 前天
        if let r = try? NSRegularExpression(pattern: #"前天"#) {
            ps.append((r, { _, _, now in
                let cal = Calendar.current
                return cal.date(byAdding: .day, value: -2, to: now) ?? now
            }))
        }
        // (\d+)\s*天前
        if let r = try? NSRegularExpression(pattern: #"(\d+)\s*天前"#) {
            ps.append((r, { m, s, now in
                guard let m = m, m.numberOfRanges > 1,
                      let nRange = Range(m.range(at: 1), in: s) else { return nil }
                let n = Int(s[nRange]) ?? 0
                let cal = Calendar.current
                return cal.date(byAdding: .day, value: -n, to: now) ?? now
            }))
        }
        // 上周[日一二三四五六末天]
        if let r = try? NSRegularExpression(pattern: #"上周([日一二三四五六末天])"#) {
            ps.append((r, { m, s, now in
                guard let m = m, m.numberOfRanges > 1,
                      let cRange = Range(m.range(at: 1), in: s),
                      let c = s[cRange].first else { return nil }
                let targetWd = wdMap[c] ?? 0
                let cal = Calendar.current
                let todayWd = (cal.component(.weekday, from: now) - 1 + 7) % 7  // 0=Sun..6=Sat
                let offset = (todayWd - targetWd + 7) % 7 + 7
                return cal.date(byAdding: .day, value: -offset, to: now) ?? now
            }))
        }
        // 上[一二三四五]周[日一二三四五六末天]
        if let r = try? NSRegularExpression(pattern: #"上([一二三四五])周([日一二三四五六末天])"#) {
            ps.append((r, { m, s, now in
                guard let m = m, m.numberOfRanges > 2,
                      let wRange = Range(m.range(at: 2), in: s),
                      let c = s[wRange].first else { return nil }
                let targetWd = wdMap[c] ?? 0
                let cal = Calendar.current
                let todayWd = (cal.component(.weekday, from: now) - 1 + 7) % 7
                let offset = (todayWd - targetWd + 7) % 7 + 7
                return cal.date(byAdding: .day, value: -offset, to: now) ?? now
            }))
        }
        // (?!上)周[日一二三四五六末天]
        if let r = try? NSRegularExpression(pattern: #"(?<!上)周([日一二三四五六末天])"#) {
            ps.append((r, { m, s, now in
                guard let m = m, m.numberOfRanges > 1,
                      let cRange = Range(m.range(at: 1), in: s),
                      let c = s[cRange].first else { return nil }
                let targetWd = wdMap[c] ?? 0
                let cal = Calendar.current
                let todayWd = (cal.component(.weekday, from: now) - 1 + 7) % 7  // 0=Sun
                var offset = targetWd - todayWd
                if offset > 0 { offset -= 7 }
                return cal.date(byAdding: .day, value: offset, to: now) ?? now
            }))
        }
        // M月D日 / M-D / M/D
        if let r = try? NSRegularExpression(pattern: #"(\d{1,2})\s*[月\-/]\s*(\d{1,2})\s*[日号]?"#) {
            ps.append((r, { m, s, now in
                guard let m = m, m.numberOfRanges > 2,
                      let mRange = Range(m.range(at: 1), in: s),
                      let dRange = Range(m.range(at: 2), in: s) else { return nil }
                let M = Int(s[mRange]) ?? 0
                let D = Int(s[dRange]) ?? 0
                guard M >= 1 && M <= 12 && D >= 1 && D <= 31 else { return nil }
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .hour, .minute, .second], from: now)
                comps.month = M
                comps.day = D
                guard var d = cal.date(from: comps) else { return nil }
                if d > now {
                    comps.year = (comps.year ?? 0) - 1
                    d = cal.date(from: comps) ?? d
                }
                return d
            }))
        }
        // YYYY年M月D日 / YYYY-M-D / YYYY/M/D
        if let r = try? NSRegularExpression(pattern: #"(\d{4})\s*[年\-/]\s*(\d{1,2})\s*[月\-/]\s*(\d{1,2})\s*[日号]?"#) {
            ps.append((r, { m, s, now in
                guard let m = m, m.numberOfRanges > 3,
                      let yRange = Range(m.range(at: 1), in: s),
                      let mRange = Range(m.range(at: 2), in: s),
                      let dRange = Range(m.range(at: 3), in: s) else { return nil }
                let Y = Int(s[yRange]) ?? 0
                let M = Int(s[mRange]) ?? 0
                let D = Int(s[dRange]) ?? 0
                guard M >= 1 && M <= 12 && D >= 1 && D <= 31 else { return nil }
                let cal = Calendar.current
                var comps = cal.dateComponents([.hour, .minute, .second], from: now)
                comps.year = Y
                comps.month = M
                comps.day = D
                return cal.date(from: comps)
            }))
        }

        return ps
    }()

    private static func extractDate(from text: String, now: Date) -> (String, Date)? {
        let range = NSRange(text.startIndex..., in: text)
        for (regex, handler) in datePatterns {
            if let match = regex.firstMatch(in: text, range: range),
               let date = handler(match, text, now) {
                var cleaned = text
                if let fullMatchRange = Range(match.range, in: text) {
                    cleaned.removeSubrange(fullMatchRange)
                }
                return (cleaned, date)
            }
        }
        return nil
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

        // tags：去重但保留用户书写顺序
        var tags: [String] = []
        var seen = Set<String>()
        for match in matches {
            if match.numberOfRanges > 1,
               let tagRange = Range(match.range(at: 1), in: text) {
                let tag = String(text[tagRange])
                if !seen.contains(tag) {
                    seen.insert(tag)
                    tags.append(tag)
                }
            }
        }

        // 从原 text 上删除所有 #xxx（matches 里的 range 是相对原 text 的）
        var cleaned = text
        for match in matches.reversed() {
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
