import Foundation
import SwiftUI

/// 统计数据（从 records 派生）
struct Statistics: Equatable {
    struct CategoryStat: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let amount: Double
        let percent: Double
        let color: Color
    }

    struct DayBar: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let label: String
        let amount: Double
        let percent: Double   // 0-100, 相对最大
    }

    struct TagCount: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let count: Int
    }

    var monthLabel: String
    var monthTotal: Double
    var monthCount: Int
    var monthDeltaPercent: Double?   // 同比上月
    var categories: [CategoryStat]
    var weekBars: [DayBar]
    var topTags: [TagCount]
}

@MainActor
enum StatisticsCalculator {
    static func compute(records: [Record], reference: Date = Date()) -> Statistics {
        let visible = records.filter { !$0.deleted }
        let cal = Calendar.current

        // 本月
        let monthComp = cal.dateComponents([.year, .month], from: reference)
        let thisMonth = visible.filter {
            let c = cal.dateComponents([.year, .month], from: $0.createdAt)
            return c.year == monthComp.year && c.month == monthComp.month
        }

        let monthTotal = thisMonth.compactMap { $0.amount }.reduce(0, +)
        let monthCount = thisMonth.count

        // 上月
        let lastMonthRef = cal.date(byAdding: .month, value: -1, to: reference) ?? reference
        let lastComp = cal.dateComponents([.year, .month], from: lastMonthRef)
        let lastMonth = visible.filter {
            let c = cal.dateComponents([.year, .month], from: $0.createdAt)
            return c.year == lastComp.year && c.month == lastComp.month
        }
        let lastTotal = lastMonth.compactMap { $0.amount }.reduce(0, +)
        let monthDelta: Double? = lastTotal > 0
            ? (monthTotal - lastTotal) / lastTotal * 100
            : nil

        // 分类（按 # 第一个标签聚合）
        var catMap: [String: Double] = [:]
        for r in thisMonth {
            let cat = r.tags.first ?? "其他"
            catMap[cat, default: 0] += r.amount ?? 0
        }
        let categories = catMap
            .map { (name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
            .map { stat -> Statistics.CategoryStat in
                Statistics.CategoryStat(
                    name: stat.name,
                    amount: stat.amount,
                    percent: monthTotal > 0 ? stat.amount / monthTotal * 100 : 0,
                    color: colorFor(stat.name)
                )
            }

        // 最近 7 天
        var weekBars: [Statistics.DayBar] = []
        for i in stride(from: 6, through: 0, by: -1) {
            let d = cal.date(byAdding: .day, value: -i, to: reference) ?? reference
            let start = cal.startOfDay(for: d)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let day = visible.filter { $0.createdAt >= start && $0.createdAt < end }
            let amt = day.compactMap { $0.amount }.reduce(0, +)
            let label = i == 0 ? "今" : "\(cal.component(.day, from: d))"
            weekBars.append(Statistics.DayBar(
                date: start,
                label: label,
                amount: amt,
                percent: 0  // 后面统一算
            ))
        }
        let maxAmt = weekBars.map { $0.amount }.max() ?? 1
        weekBars = weekBars.map { bar in
            Statistics.DayBar(
                date: bar.date,
                label: bar.label,
                amount: bar.amount,
                percent: maxAmt > 0 ? bar.amount / maxAmt * 100 : 0
            )
        }

        // 全部标签 Top 10
        var tagMap: [String: Int] = [:]
        for r in visible { for t in r.tags { tagMap[t, default: 0] += 1 } }
        let topTags = tagMap.sorted { $0.value > $1.value }.prefix(10).map {
            Statistics.TagCount(name: $0.key, count: $0.value)
        }

        // 月份标签
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        let monthLabel = f.string(from: reference)

        return Statistics(
            monthLabel: monthLabel,
            monthTotal: monthTotal,
            monthCount: monthCount,
            monthDeltaPercent: monthDelta,
            categories: categories,
            weekBars: weekBars,
            topTags: Array(topTags)
        )
    }

    private static func colorFor(_ name: String) -> Color {
        let palette: [Color] = [
            Theme.green,
            Color(red: 0.09, green: 0.47, blue: 1.00),   // 蓝
            Theme.warn,
            Color(red: 0.45, green: 0.18, blue: 0.82),   // 紫
            Color(red: 0.07, green: 0.76, blue: 0.76),   // 青
            Color(red: 0.92, green: 0.18, blue: 0.59),   // 粉
            Color(red: 0.55, green: 0.55, blue: 0.55)
        ]
        var h: UInt32 = 5381
        for c in name.unicodeScalars { h = ((h << 5) &+ h) &+ c.value }
        return palette[Int(h) % palette.count]
    }
}
