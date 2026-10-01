import Foundation

public enum VeilgramArchiveRuntimeDiagnostics {
    private static let lock = NSLock()
    private static var value: String?

    public static var lastErrorDescription: String? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    static func record(_ error: Error) {
        lock.lock()
        value = String(describing: error)
        lock.unlock()
    }

    public static func clear() {
        lock.lock()
        value = nil
        lock.unlock()
    }
}

public enum VeilgramArchiveRuntimeWriter {
    private struct DeletedMessageEvent {
        let message: VeilgramArchivedMessage
        let eligibility: VeilgramArchiveEligibility
    }

    private struct EditRevisionEvent {
        let key: VeilgramMessageKey
        let revision: VeilgramEditRevision
        let eligibility: VeilgramArchiveEligibility
    }

    private struct PendingAccountBatch {
        var deletedMessages: [VeilgramMessageKey: DeletedMessageEvent] = [:]
        var deletedMessageOrder: [VeilgramMessageKey] = []
        var editRevisions: [EditRevisionEvent] = []
        var lastPendingEditRevision: [VeilgramMessageKey: VeilgramEditRevision] = [:]

        var eventCount: Int {
            return deletedMessages.count + editRevisions.count
        }

        mutating func appendDeletedMessage(
            _ message: VeilgramArchivedMessage,
            eligibility: VeilgramArchiveEligibility
        ) {
            if deletedMessages[message.key] == nil {
                deletedMessageOrder.append(message.key)
            }
            deletedMessages[message.key] = DeletedMessageEvent(
                message: message,
                eligibility: eligibility
            )
        }

        mutating func appendEditRevision(
            key: VeilgramMessageKey,
            revision: VeilgramEditRevision,
            eligibility: VeilgramArchiveEligibility
        ) {
            guard lastPendingEditRevision[key] != revision else {
                return
            }
            lastPendingEditRevision[key] = revision
            editRevisions.append(
                EditRevisionEvent(
                    key: key,
                    revision: revision,
                    eligibility: eligibility
                )
            )
        }
    }

    private static let queue = DispatchQueue(
        label: "org.veilgram.local-archive",
        qos: .utility,
        autoreleaseFrequency: .workItem
    )

    // A short debounce coalesces bursts of delete/edit updates into one JSON
    // read/decode + one atomic write per document. The size cap prevents a
    // sustained stream from growing the in-memory batch without bound.
    private static let flushDelay: DispatchTimeInterval = .milliseconds(150)
    private static let maximumPendingEventsPerAccount = 128

    // Queue-confined state. These values are only read or mutated on `queue`.
    private static var pendingBatches: [Int64: PendingAccountBatch] = [:]
    private static var flushScheduled = false

    public static func enqueueDeletedMessage(
        accountPeerId: Int64,
        message: VeilgramArchivedMessage,
        eligibility: VeilgramArchiveEligibility
    ) {
        guard VeilgramArchiveRuntimePreferences.messageArchiveEnabled(accountPeerId: accountPeerId),
              eligibility.isEligibleForLocalRetention else {
            return
        }

        queue.async {
            var batch = pendingBatches[accountPeerId] ?? PendingAccountBatch()
            batch.appendDeletedMessage(message, eligibility: eligibility)
            pendingBatches[accountPeerId] = batch

            if batch.eventCount >= maximumPendingEventsPerAccount {
                flush(accountPeerId: accountPeerId)
            } else {
                scheduleFlushIfNeeded()
            }
        }
    }

    public static func enqueuePreviousEditRevision(
        accountPeerId: Int64,
        key: VeilgramMessageKey,
        revision: VeilgramEditRevision,
        eligibility: VeilgramArchiveEligibility
    ) {
        guard VeilgramArchiveRuntimePreferences.editHistoryEnabled(accountPeerId: accountPeerId),
              eligibility.isEligibleForLocalRetention else {
            return
        }

        queue.async {
            var batch = pendingBatches[accountPeerId] ?? PendingAccountBatch()
            batch.appendEditRevision(
                key: key,
                revision: revision,
                eligibility: eligibility
            )
            pendingBatches[accountPeerId] = batch

            if batch.eventCount >= maximumPendingEventsPerAccount {
                flush(accountPeerId: accountPeerId)
            } else {
                scheduleFlushIfNeeded()
            }
        }
    }

    /// Requests an asynchronous flush on the same serial writer queue.
    /// This never blocks the caller, including callers on the UI thread.
    public static func flushPending() {
        queue.async {
            flushAll()
        }
    }

    private static func scheduleFlushIfNeeded() {
        guard !flushScheduled else {
            return
        }
        flushScheduled = true
        queue.asyncAfter(deadline: .now() + flushDelay) {
            flushScheduled = false
            flushAll()
        }
    }

    private static func flushAll() {
        let accountPeerIds = Array(pendingBatches.keys)
        for accountPeerId in accountPeerIds {
            flush(accountPeerId: accountPeerId)
        }
    }

    private static func flush(accountPeerId: Int64) {
        guard let batch = pendingBatches.removeValue(forKey: accountPeerId) else {
            return
        }

        do {
            let store = try VeilgramArchiveStoreAPI(accountId: accountPeerId)

            if !batch.deletedMessageOrder.isEmpty {
                flushDeletedMessages(batch, store: store)
            }
            if !batch.editRevisions.isEmpty {
                flushEditRevisions(batch, store: store)
            }
        } catch {
            VeilgramArchiveRuntimeDiagnostics.record(error)
        }
    }

    private static func flushDeletedMessages(
        _ batch: PendingAccountBatch,
        store: VeilgramArchiveStoreAPI
    ) {
        do {
            var document = try store.loadMessages()
            var changed = false

            for key in batch.deletedMessageOrder {
                guard let event = batch.deletedMessages[key] else {
                    continue
                }
                do {
                    if try VeilgramMessageArchiveEngine.append(
                        document: &document,
                        message: event.message,
                        eligibility: event.eligibility
                    ) {
                        changed = true
                    }
                } catch {
                    VeilgramArchiveRuntimeDiagnostics.record(error)
                }
            }

            if changed {
                try store.saveMessages(document)
            }
        } catch {
            VeilgramArchiveRuntimeDiagnostics.record(error)
        }
    }

    private static func flushEditRevisions(
        _ batch: PendingAccountBatch,
        store: VeilgramArchiveStoreAPI
    ) {
        do {
            var document = try store.loadEdits()
            var changed = false

            for event in batch.editRevisions {
                do {
                    if try VeilgramEditHistoryEngine.append(
                        document: &document,
                        key: event.key,
                        revision: event.revision,
                        eligibility: event.eligibility
                    ) {
                        changed = true
                    }
                } catch {
                    VeilgramArchiveRuntimeDiagnostics.record(error)
                }
            }

            if changed {
                try store.saveEdits(document)
            }
        } catch {
            VeilgramArchiveRuntimeDiagnostics.record(error)
        }
    }
}
