import SwiftUI

struct StatsView: View {
    @ObservedObject var store: RecordStore
    @State private var stats: Statistics = Statistics(
        monthLabel: "", monthTotal: 0, monthCount: 0, monthDeltaPercent: nil,
        categories: [], weekBars: [], topTags: []
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 顶部月份 + 同步状态
                HStack {
                    Text(stats.monthLabel)
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 4)

                // 大数字
                HStack(spacing: 16) {
                    bigCard(
                        label: "本月支出",
                        value: String(format: "¥%.0f", stats.monthTotal),
                        sub: stats.monthDeltaPercent.map { delta in
                            let arrow = delta >= 0 ? "↑" : "↓"
                            return "\(arrow) \(String(format: "%.0f", abs(delta)))% vs 上月"
                        } ?? "无对比数据",
                        deltaColor: (stats.monthDeltaPercent ?? 0) >= 0 ? Theme.warn : Theme.greenDeep
                    )
                    bigCard(
                        label: "记录数",
                        value: "\(stats.monthCount)",
                        sub: "笔 · 全部类型",
                        deltaColor: Theme.text3
                    )
                }

                // 分类环形图
                if !stats.categories.isEmpty {
                    sectionTitle("分类占比")
                    HStack(alignment: .top, spacing: 16) {
                        donut
                            .frame(width: 110, height: 110)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(stats.categories.prefix(5)) { cat in
                                catRow(cat)
                            }
                        }
                    }
                    .padding(16)
                    .background(cardBg)
                }

                // 最近 7 天
                if stats.weekBars.contains(where: { $0.amount > 0 }) || true {
                    sectionTitle("最近 7 天")
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(stats.weekBars) { bar in
                            VStack(spacing: 4) {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(bar.label == "今" ? Theme.green : Theme.greenSoft)
                                    .frame(maxWidth: 32)
                                    .frame(height: max(4, CGFloat(bar.percent) * 0.5))
                                Text(bar.label)
                                    .font(.system(size: 10))
                                    .foregroundColor(bar.label == "今" ? Theme.greenDeep : Theme.text3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 80)
                    .padding(16)
                    .background(cardBg)
                }

                // 热门标签
                if !stats.topTags.isEmpty {
                    sectionTitle("热门标签")
                    FlowLayout(spacing: 6) {
                        ForEach(stats.topTags) { tag in
                            HStack(spacing: 4) {
                                Text("#\(tag.name)")
                                Text("\(tag.count)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Theme.text3)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.greenDeep)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.rChip)
                                    .fill(Theme.greenSoft)
                            )
                        }
                    }
                    .padding(16)
                    .background(cardBg)
                }
            }
            .padding(20)
        }
        .background(Theme.page)
        .onAppear { refresh() }
        .onChange(of: store.records) { _ in refresh() }
    }

    private func refresh() {
        stats = StatisticsCalculator.compute(records: store.records)
    }

    // MARK: - Sub-views

    private func bigCard(label: String, value: String, sub: String, deltaColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.text3)
            Text(value)
                .font(.system(size: 24, weight: .semibold).monospacedDigit())
                .foregroundColor(Theme.text1)
            Text(sub)
                .font(.system(size: 11))
                .foregroundColor(deltaColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBg)
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Theme.text3)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.horizontal, 4)
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: Theme.rCard)
            .fill(Color.white)
    }

    private func catRow(_ cat: Statistics.CategoryStat) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(cat.color)
                .frame(width: 8, height: 8)
            Text(cat.name)
                .font(.system(size: 12))
                .foregroundColor(Theme.text1)
            Spacer()
            Text(String(format: "¥%.0f", cat.amount))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.text2)
        }
    }

    private var donut: some View {
        ZStack {
            ForEach(Array(stats.categories.enumerated()), id: \.element.id) { (i, cat) in
                Circle()
                    .trim(from: trimStart(i), to: trimEnd(i))
                    .stroke(cat.color, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text("\(Int(stats.categories.first?.percent ?? 0))%")
                    .font(.system(size: 18, weight: .semibold))
                Text(stats.categories.first?.name ?? "—")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.text3)
            }
        }
    }

    private func trimStart(_ i: Int) -> Double {
        let total = stats.categories.reduce(0) { $0 + $1.percent }
        guard total > 0 else { return 0 }
        let before = stats.categories.prefix(i).reduce(0) { $0 + $1.percent }
        return before / total
    }

    private func trimEnd(_ i: Int) -> Double {
        let total = stats.categories.reduce(0) { $0 + $1.percent }
        guard total > 0 else { return 1 }
        let upTo = stats.categories.prefix(i + 1).reduce(0) { $0 + $1.percent }
        return upTo / total
    }
}

/// 极简 FlowLayout（横向 wrap）
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            s.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
