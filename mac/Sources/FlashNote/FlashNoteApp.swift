import SwiftUI
import AppKit

@main
struct FlashNoteApp: App {
    @StateObject private var store = RecordStore()
    @StateObject private var sync: SyncCoordinator
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        let store = RecordStore()
        let sync = SyncCoordinator(store: store)
        _store = StateObject(wrappedValue: store)
        _sync = StateObject(wrappedValue: sync)
    }

    var body: some Scene {
        WindowGroup("闪记") {
            ContentView()
                .environmentObject(store)
                .environmentObject(sync)
                .onAppear { sync.start() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("快速记录") {
                    NotificationCenter.default.post(name: .flashnoteToggleQuickRecord, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}

/// 保留一个 AppDelegate 钩子，方便 M3 同步层挂服务
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置 app icon（从 bundle 资源加载）
        if let url = Bundle.module.url(forResource: "icon-1024", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = image
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
