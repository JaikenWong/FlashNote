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
        NSLog("[SyncCoordinator] start() called")
        let store = self.store
        let server = SyncServer(
            port: port,
            pairManager: pairManager,
            tokenStore: tokenStore,
            recordsProvider: { store.records },
            recordsApplier: { [weak self] incoming in
                guard let self = self else { return }
                self.applyIncoming(incoming)
            }
        )
        let advertiser = MDNSAdvertiser(port: port)
        do {
            NSLog("[SyncCoordinator] starting server...")
            try server.start()
            NSLog("[SyncCoordinator] server started")
            try advertiser.start()
            NSLog("[SyncCoordinator] advertiser started")
            self.server = server
            self.advertiser = advertiser
            self.isRunning = true
            NSLog("[SyncCoordinator] started on port \(port) · code=\(currentPairCode)")
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
