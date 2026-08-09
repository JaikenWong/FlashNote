import SwiftUI

struct CardListView: View {
    @ObservedObject var store: RecordStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if store.visibleRecords.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedByMonth, id: \.month) { group in
                        MonthGroupView(month: group.month, sum: group.sum, count: group.count) {
                            ForEach(group.records) { record in
                                CardView(record: record) {
                                    store.delete(record)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 100)  // 给底部 quick input 留空间
        }
        .background(Theme.page)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📝")
                .font(.system(size: 48))
            Text("还没有记录")
                .font(.system(size: 14))
                .foregroundColor(Theme.text3)
            Text("试试在底部输入 午饭 28 #餐")
                .font(.system(size: 12))
                .foregroundColor(Theme.text4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private struct MonthGroup {
        let month: String
        let sum: Double
        let count: Int
        let records: [Record]
    }

    private var groupedByMonth: [MonthGroup] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"

        var groups: [String: [Record]] = [:]
        var order: [String] = []
        for r in store.visibleRecords {
            let comps = cal.dateComponents([.year, .month], from: r.createdAt)
            guard let date = cal.date(from: comps) else { continue }
            let key = formatter.string(from: date)
            if groups[key] == nil {
                groups[key] = []
                order.append(key)
            }
            groups[key]?.append(r)
        }

        return order.map { key in
            let rs = groups[key] ?? []
            let sum = rs.compactMap { $0.amount }.reduce(0, +)
            return MonthGroup(month: key, sum: sum, count: rs.count, records: rs)
        }
    }
}

/// 单个月份分组
struct MonthGroupView<Content: View>: View {
    let month: String
    let sum: Double
    let count: Int
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(month)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.text3)
                if sum > 0 {
                    Text("· 支出")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.text3)
                    Text(String(format: "¥%.0f", sum))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.greenDeep)
                }
                Spacer()
            }
            .padding(.horizontal, 4)

            content
        }
    }
}
