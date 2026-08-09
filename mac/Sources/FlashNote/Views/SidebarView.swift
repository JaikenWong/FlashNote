import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: RecordStore
    @Binding var mainView: ContentView.MainViewKind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 视图
            sectionHeader("视图")
            viewButton(.cards, icon: "≡", label: "全部")
            viewButton(.stats, icon: "📊", label: "统计")

            // 分类区
            sectionHeader("分类")
            navItem(.all, icon: "≡", label: "全部", count: store.records.filter { !$0.deleted }.count)
            navItem(.note, icon: "📝", label: "笔记", count: count(of: .note))
            navItem(.expense, icon: "💰", label: "账目", count: count(of: .expense))

            // 标签区
            if !store.allTags.isEmpty {
                sectionHeader("标签")
                ForEach(store.allTags.prefix(12), id: \.0) { (name, count) in
                    navItem(.tag(name), icon: "#", label: name, count: count)
                }
            }

            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(Theme.sidebar)
    }

    private func sectionHeader(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Theme.text3)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .padding(.top, 6)
    }

    private func count(of type: RecordType) -> Int {
        store.records.filter { !$0.deleted && $0.type == type }.count
    }

    @ViewBuilder
    private func viewButton(_ kind: ContentView.MainViewKind, icon: String, label: String) -> some View {
        let isActive = mainView == kind
        Button {
            mainView = kind
        } label: {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                    .foregroundColor(isActive ? Theme.green : Theme.text3)
                Text(label)
                    .font(.system(size: 13, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? Theme.greenDeep : Theme.text2)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.rBtn)
                    .fill(isActive ? Theme.greenSoft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func navItem(_ filter: RecordStore.Filter, icon: String, label: String, count: Int) -> some View {
        let isActive = store.filter == filter
        Button {
            store.filter = filter
            mainView = .cards
        } label: {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                    .foregroundColor(isActive ? Theme.green : Theme.text3)
                Text(label)
                    .font(.system(size: 13, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? Theme.greenDeep : Theme.text2)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isActive ? Theme.greenDeep : Theme.text3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.rBtn)
                    .fill(isActive ? Theme.greenSoft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }
}
