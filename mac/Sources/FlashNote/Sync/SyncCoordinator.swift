import Foundation
import Combine

/// 同步协调器：启动 mDNS + HTTP server
@MainActor
final class SyncCoordinator: ObservableObject {
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var connectedClients: Int = 0

    private let store: RecordStore
    private let pairManager: PairCodeManager
    private let tokenStore: SyncTokenStore
    private var server: SyncServer?
    private var advertiser: MDNSAdvertiser?
    private let port: UInt16 = 9527

    init(store: RecordStore) {
        self.store = store
        self.pairManager = PairCodeManager()
        self.tokenStore = SyncTokenStore()
    }

    var currentPairCode: String { pairManager.code }

    func regenerateCode() {
        pairManager.regenerate()
        objectWillChange.send()
    }

    func start() {
        guard !isRunning else { return }
        let store = self.store
        let server = SyncServer(
            port: port,
            pairManager: pairManager,
            tokenStore: tokenStore,
            recordsProvider: { [store] in
                // 主线程读，避免后台线程并发访问 @Published 数组
                if Thread.isMainThread { return store.records }
                return DispatchQueue.main.sync { store.records }
            },
            recordsApplier: { [weak self] incoming in
                guard let self = self else { return }
                // @MainActor 跳转：applyIncoming 里的 store.mergeFromRemote
                // 会改 @Published records，必须在主线程执行
                DispatchQueue.main.async {
                    self.applyIncoming(incoming)
                }
            }
        )
        let advertiser = MDNSAdvertiser(port: port)
        do {
            try server.start()
            try advertiser.start()
            self.server = server
            self.advertiser = advertiser
            self.isRunning = true
        } catch {
            NSLog("[SyncCoordinator] failed: %@", String(describing: error))
        }
    }

    func stop() {
        server?.stop()
        advertiser?.stop()
        server = nil
        advertiser = nil
        isRunning = false
    }

    // MARK: - LWW merge（主线程调用：UI 交互时）

    private func applyIncoming(_ incoming: [Record]) {
        store.mergeFromRemote(incoming)
    }
}
