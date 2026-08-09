import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RecordStore
    @EnvironmentObject var sync: SyncCoordinator
    @State private var showQuickRecord = false
    @State private var showSyncSettings = false
    @State private var showExport = false
    @State private var lastInserted: Record?
    @State private var mainView: MainViewKind = .cards
    @State private var editingRecord: Record? = nil

    enum MainViewKind { case cards, stats }

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                SidebarView(store: store, mainView: $mainView)
                    .frame(width: 200)

                mainArea
            }

            // 底部浮动输入条（仅在 cards 视图显示）
            if mainView == .cards {
                QuickInputBar(store: store) { record in
                    lastInserted = record
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .frame(minWidth: 800, minHeight: 540)
        .background(Theme.page)
        .overlay {
            if showQuickRecord {
                QuickRecordModal(store: store, isOpen: $showQuickRecord)
                    .onAppear {
                        if let r = editingRecord {
                            NotificationCenter.default.post(
                                name: .flashnoteEditRecord,
                                object: r
                            )
                            editingRecord = nil
                        }
                    }
            }
            if showSyncSettings {
                SyncSettingsModal(sync: sync, isOpen: $showSyncSettings)
            }
            if showExport {
                ExportModal(store: store, isOpen: $showExport)
            }
        }
        // Cmd+N 唤起快速记录
        .onReceive(NotificationCenter.default.publisher(for: .flashnoteToggleQuickRecord)) { _ in
            editingRecord = nil
            showQuickRecord.toggle()
        }
    }

    private var mainArea: some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack(spacing: 12) {
                // 搜索（仅在 cards 视图）
                if mainView == .cards {
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
                }

                Spacer()

                // 导出按钮
                Button {
                    showExport = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text("导出")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Theme.text2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color(white: 0.96))
                    )
                }
                .buttonStyle(.plain)

                // 同步状态 pill
                Button {
                    showSyncSettings = true
                } label: {
                    SyncStatusPill(state: sync.isRunning ? .synced : .local, code: sync.currentPairCode)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 48)
            .background(Color.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            // 主体
            switch mainView {
            case .cards:  CardListView(store: store, onEdit: { r in
                editingRecord = r
                showQuickRecord = true
            })
            case .stats:  StatsView(store: store)
            }
        }
    }
}

/// 同步状态
enum SyncState: Equatable { case local, syncing, synced, error(String) }

struct SyncStatusPill: View {
    let state: SyncState
    var code: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .medium))
            if let code = code, state == .synced {
                Text("·")
                    .foregroundColor(Theme.text3)
                Text(code)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.greenDeep)
            }
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
        case .syncing: return "局域网 · 配对码"
        case .synced:  return "局域网"
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

/// 同步设置浮层（M3）
struct SyncSettingsModal: View {
    @ObservedObject var sync: SyncCoordinator
    @Binding var isOpen: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.08).ignoresSafeArea()
                .onTapGesture { isOpen = false }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("局域网同步")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button("关闭") { isOpen = false }
                        .buttonStyle(.plain)
                        .foregroundColor(Theme.text3)
                }

                // 配对码大数字
                VStack(spacing: 4) {
                    Text("在微信小程序「闪记」中输入配对码")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.text2)
                    Text(formatCode(sync.currentPairCode))
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .tracking(8)
                        .foregroundColor(Theme.greenDeep)
                    Text("端口 9527 · 需在同一 WiFi 下")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text3)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.greenSoft)
                )

                HStack {
                    Circle()
                        .fill(sync.isRunning ? Theme.green : Theme.text4)
                        .frame(width: 8, height: 8)
                    Text(sync.isRunning ? "HTTP server + mDNS 已启动" : "未启动")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.text2)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button {
                        sync.regenerateCode()
                    } label: {
                        Text("重新生成配对码")
                            .font(.system(size: 13))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Theme.border2, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(width: 440)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 8)
            )
        }
    }

    private func formatCode(_ c: String) -> String {
        c.map { String($0) }.joined(separator: " ")
    }
}

extension Notification.Name {
    static let flashnoteToggleQuickRecord = Notification.Name("FlashNote.toggleQuickRecord")
    static let flashnoteEditRecord = Notification.Name("FlashNote.editRecord")
}
