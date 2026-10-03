import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit
import VeilgramLocalFeatures

private typealias SignalKitTimer = SwiftSignalKit.Timer


private final class AccountPresenceManagerImpl {
    private let queue: Queue
    private let network: Network
    private let accountPeerId: PeerId
    let isPerformingUpdate = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private var shouldKeepOnlinePresenceDisposable: Disposable?
    private let currentRequestDisposable = MetaDisposable()
    private let peekRequestDisposable = MetaDisposable()
    private var peekObserver: NSObjectProtocol?
    private var onlineTimer: SignalKitTimer?
    private var peekTimer: SignalKitTimer?
    
    private var wasOnline: Bool = false
    
    init(queue: Queue, shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network, accountPeerId: PeerId) {
        self.queue = queue
        self.network = network
        self.accountPeerId = accountPeerId
        
        self.shouldKeepOnlinePresenceDisposable = (shouldKeepOnlinePresence
        |> distinctUntilChanged
        |> deliverOn(self.queue)).start(next: { [weak self] value in
            guard let `self` = self else {
                return
            }
            if self.wasOnline != value {
                self.wasOnline = value
                self.updatePresence(value)
            }
        })

        self.peekObserver = NotificationCenter.default.addObserver(
            forName: VeilgramGhostModeRuntimePreferences.peekOnlineNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self,
                  let value = notification.object as? NSNumber,
                  value.int64Value == self.accountPeerId.toInt64() else {
                return
            }
            self.queue.async {
                self.performPeekOnline()
            }
        }
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.shouldKeepOnlinePresenceDisposable?.dispose()
        self.currentRequestDisposable.dispose()
        self.peekRequestDisposable.dispose()
        if let peekObserver {
            NotificationCenter.default.removeObserver(peekObserver)
        }
        self.onlineTimer?.invalidate()
        self.peekTimer?.invalidate()
    }
    
    private func performPeekOnline() {
        guard VeilgramGhostModeRuntimePreferences.suppressOnlinePresence(
            accountPeerId: self.accountPeerId.toInt64()
        ) else {
            return
        }

        self.peekTimer?.invalidate()
        self.peekTimer = nil

        let request = self.network.request(
            Api.functions.account.updateStatus(offline: .boolFalse)
        )
        self.peekRequestDisposable.set((
            request
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> deliverOn(self.queue)
        ).start(completed: { [weak self] in
            guard let self else {
                return
            }
            let timer = SignalKitTimer(
                timeout: 8.0,
                repeat: false,
                completion: { [weak self] in
                    self?.updatePresence(false)
                },
                queue: self.queue
            )
            self.peekTimer = timer
            timer.start()
        }))
    }

    private func updatePresence(_ isOnline: Bool) {
        let effectiveIsOnline = isOnline && !VeilgramGhostModeRuntimePreferences.suppressOnlinePresence(
            accountPeerId: self.accountPeerId.toInt64()
        )
        let request: Signal<Api.Bool, MTRpcError>
        if effectiveIsOnline {
            let timer = SignalKitTimer(timeout: 30.0, repeat: false, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updatePresence(true)
            }, queue: self.queue)
            self.onlineTimer = timer
            timer.start()
            request = self.network.request(Api.functions.account.updateStatus(offline: .boolFalse))
        } else {
            self.onlineTimer?.invalidate()
            self.onlineTimer = nil
            request = self.network.request(Api.functions.account.updateStatus(offline: .boolTrue))
        }
        self.isPerformingUpdate.set(true)
        self.currentRequestDisposable.set((request
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> deliverOn(self.queue)).start(completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isPerformingUpdate.set(false)
        }))
    }
}

final class AccountPresenceManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<AccountPresenceManagerImpl>
    
    init(shouldKeepOnlinePresence: Signal<Bool, NoError>, network: Network, accountPeerId: PeerId) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: self.queue, generate: {
            return AccountPresenceManagerImpl(queue: queue, shouldKeepOnlinePresence: shouldKeepOnlinePresence, network: network, accountPeerId: accountPeerId)
        })
    }
    
    func isPerformingUpdate() -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.isPerformingUpdate.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
}
