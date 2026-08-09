import SwiftUI

/// 设计令牌：与 DESIGN.md §6.1 保持一致
enum Theme {
    // 颜色
    static let green       = Color(red: 0.32, green: 0.77, blue: 0.10)  // #52C41A
    static let greenSoft   = Color(red: 0.96, green: 1.00, blue: 0.93)  // #F6FFED
    static let greenDeep   = Color(red: 0.22, green: 0.62, blue: 0.05)  // #389E0D
    static let greenFaint  = Color(red: 0.91, green: 0.96, blue: 0.85)  // #E8F5D8

    static let warn        = Color(red: 0.98, green: 0.68, blue: 0.08)  // #FAAD14
    static let warnSoft    = Color(red: 1.00, green: 0.97, blue: 0.90)  // #FFF7E6

    static let bg          = Color.white
    static let page        = Color(red: 0.98, green: 0.98, blue: 0.98)  // #FAFAFA
    static let sidebar     = Color(red: 0.99, green: 0.99, blue: 0.99)

    static let text1       = Color(red: 0.12, green: 0.12, blue: 0.12)  // #1F1F1F
    static let text2       = Color(red: 0.35, green: 0.35, blue: 0.35)  // #595959
    static let text3       = Color(red: 0.55, green: 0.55, blue: 0.55)  // #8C8C8C
    static let text4       = Color(red: 0.75, green: 0.75, blue: 0.75)  // #BFBFBF

    static let border      = Color(red: 0.94, green: 0.94, blue: 0.94)  // #F0F0F0
    static let border2     = Color(red: 0.91, green: 0.91, blue: 0.91)  // #E8E8E8

    // 圆角
    static let rCard: CGFloat  = 12
    static let rBtn: CGFloat   = 8
    static let rChip: CGFloat  = 6
    static let rPill: CGFloat  = 999

    // 字体
    static func mono(_ size: CGFloat = 12) -> Font {
        .system(size: size, design: .monospaced)
    }
}

extension View {
    /// 卡片左侧的状态条（笔记实线 / 账目虚线）
    func cardAccent(for type: RecordType) -> some View {
        overlay(alignment: .leading) {
            Rectangle()
                .fill(type == .note ? Theme.green : Theme.warn)
                .frame(width: 3)
                .cornerRadius(2)
                .padding(.vertical, 12)
        }
    }
}
