import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RecordStore
    @State private var showQuickRecord = false
    @State private var lastInserted: Record?

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                SidebarView(store: store)
                    .frame(width: 200)

                mainArea
            }

            // 底部浮动输入条
            QuickInputBar(store: store) { record in
                lastInserted = record
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 800, minHeight: 540)
        .background(Theme.page)
        .overlay {
            if showQuickRecord {
                QuickRecordModal(store: store, isOpen: $showQuickRecord)
            }
        }
        // Cmd+N 唤起快速记录
        .onReceive(NotificationCenter.default.publisher(for: .flashnoteToggleQuickRecord)) { _ in
            showQuickRecord.toggle()
        }
    }

    private var mainArea: some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack(spacing: 12) {
                // 搜索
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.text3)
                    TextField("搜索…", text: $store.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !store.searchText.isEmpty {
                        Button {
                            store.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.text4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: Theme.rBtn)
                        .fill(Theme.page)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.rBtn)
                        .stroke(Theme.border, lineWidth: 1)
                )

                Spacer()

                // 同步状态（M3 实装，先占位）
                SyncStatusPill(state: .local)
            }
            .padding(.horizontal, 20)
            .frame(height: 48)
            .background(Color.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            // 卡片列表
            CardListView(store: store)
        }
    }
}

/// 同步状态（M3 实装，目前只显示本地）
enum SyncState { case local, syncing, synced, error(String) }

struct SyncStatusPill: View {
    let state: SyncState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(bg)
        )
    }

    private var text: String {
        switch state {
        case .local:   return "本地"
        case .syncing: return "同步中…"
        case .synced:  return "已同步"
        case .error:   return "同步失败"
        }
    }

    private var color: Color {
        switch state {
        case .local:   return Theme.text4
        case .syncing: return Theme.warn
        case .synced:  return Theme.green
        case .error:   return Color.red
        }
    }

    private var bg: Color {
        switch state {
        case .local:   return Color(white: 0.96)
        case .syncing: return Theme.warnSoft
        case .synced:  return Theme.greenSoft
        case .error:   return Color(red: 1.0, green: 0.93, blue: 0.93)
        }
    }
}

extension Notification.Name {
    static let flashnoteToggleQuickRecord = Notification.Name("FlashNote.toggleQuickRecord")
}
