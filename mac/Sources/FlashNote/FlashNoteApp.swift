import SwiftUI
import AppKit

@main
struct FlashNoteApp: App {
    @StateObject private var store = RecordStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("闪记") {
            ContentView()
                .environmentObject(store)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // 用菜单栏 File → New 触发快速记录
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
