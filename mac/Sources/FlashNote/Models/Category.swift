import Foundation
import SwiftUI

/// 预置的支出分类（M1：仅支出）
enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case meal       = "餐"
    case transport  = "交通"
    case shopping   = "购物"
    case entertainment = "娱乐"
    case home       = "居家"
    case medical    = "医疗"
    case other      = "其他"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .meal:         return "🍱"
        case .transport:    return "🚇"
        case .shopping:     return "🛍"
        case .entertainment:return "🎮"
        case .home:         return "🏠"
        case .medical:      return "💊"
        case .other:        return "✨"
        }
    }

    var color: Color {
        switch self {
        case .meal:         return Color(red: 0.32, green: 0.77, blue: 0.10)  // 绿
        case .transport:    return Color(red: 0.98, green: 0.68, blue: 0.08)  // 橙
        case .shopping:     return Color(red: 0.09, green: 0.47, blue: 1.00)  // 蓝
        case .entertainment:return Color(red: 0.45, green: 0.18, blue: 0.82)  // 紫
        case .home:         return Color(red: 0.20, green: 0.20, blue: 0.20)
        case .medical:      return Color(red: 0.92, green: 0.30, blue: 0.30)  // 红
        case .other:        return Color(red: 0.55, green: 0.55, blue: 0.55)
        }
    }
}
