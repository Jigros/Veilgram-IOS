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

struct VeilgramArchiveRuntimeBatchPolicy {
    static let flushDelayMilliseconds = 150
    static let maximumPendingEventsPerAccount = 128
    static let retryBaseDelayMilliseconds = 250
    static let retryMaximumDelayMilliseconds = 5_000

    static func retryDelayMilliseconds(attempt: Int) -> Int {
        let normalizedAttempt = max(1, attempt)
        let shift = min(normalizedAttempt - 1, 8)
        let multiplier = 1 << shift
        return min(
            retryMaximumDelayMilliseconds,
            retryBaseDelayMilliseconds * multiplier
        )
    }
}

struct VeilgramArchivePendingDeletedMessageEvent {
    let message: VeilgramArchivedMessage
    let eligibility: VeilgramArchiveEligibility
}

struct VeilgramArchivePendingEditRevisionEvent {
    let key: VeilgramMessageKey
    let revision: VeilgramEditRevision
    let eligibility: VeilgramArchiveEligibility
}

struct VeilgramArchivePendingBatch {
    var deletedMessages: [VeilgramMessageKey: VeilgramArchivePendingDeletedMessageEvent] = [:]
    var deletedMessageOrder: [VeilgramMessageKey] = []
    var editRevisions: [VeilgramArchivePendingEditRevisionEvent] = []
    var lastPendingEditRevision: [VeilgramMessageKey: VeilgramEditRevision] = [:]
    var retryAttempt = 0

    var eventCount: Int {
        return deletedMessages.count + editRevisions.count
    }

    var isEmpty: Bool {
        return deletedMessages.isEmpty && editRevisions.isEmpty
    }

    mutating func appendDeletedMessage(
        _ message: VeilgramArchivedMessage,
        eligibility: VeilgramArchiveEligibility
    ) {
        if deletedMessages[message.key] == nil {
            deletedMessageOrder.append(message.key)
        }
        deletedMessages[message.key] = VeilgramArchivePendingDeletedMessageEvent(
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
            VeilgramArchivePendingEditRevisionEvent(
                key: key,
                revision: revision,
                eligibility: eligibility
            )
        )
    }

    mutating func discardDeletedMessages() {
        deletedMessages.removeAll(keepingCapacity: false)
        deletedMessageOrder.removeAll(keepingCapacity: false)
    }

    mutating func discardEditRevisions() {
        editRevisions.removeAll(keepingCapacity: false)
        lastPendingEditRevision.removeAll(keepingCapacity: false)
    }

    func deletedMessagesOnly(nextRetryAttempt: Int) -> VeilgramArchivePendingBatch {
        var result = VeilgramArchivePendingBatch()
        result.deletedMessages = deletedMessages
        result.deletedMessageOrder = deletedMessageOrder
        result.retryAttempt = nextRetryAttempt
        return result
    }

    func editRevisionsOnly(nextRetryAttempt: Int) -> VeilgramArchivePendingBatch {
        var result = VeilgramArchivePendingBatch()
        result.editRevisions = editRevisions
        result.lastPendingEditRevision = lastPendingEditRevision
        result.retryAttempt = nextRetryAttempt
        return result
    }

    mutating func mergeNewer(_ newer: VeilgramArchivePendingBatch) {
        for key in newer.deletedMessageOrder {
            guard let event = newer.deletedMessages[key] else {
                continue
            }
            appendDeletedMessage(event.message, eligibility: event.eligibility)
        }
        for event in newer.editRevisions {
            appendEditRevision(
                key: event.key,
                revision: event.revision,
                eligibility: event.eligibility
            )
        }
        retryAttempt = max(retryAttempt, newer.retryAttempt)
    }
}

public struct VeilgramLocalMediaArchiveCandidate: Equatable {
    public var key: VeilgramMediaKey
    public var sourcePath: String?
    public var archivedAt: Int32

    public init(
        key: VeilgramMediaKey,
        sourcePath: String?,
        archivedAt: Int32
    ) {
        self.key = key
        self.sourcePath = sourcePath
        self.archivedAt = archivedAt
    }
}

public enum VeilgramArchiveRuntimeWriter {
    private static let queue = DispatchQueue(
        label: "org.veilgram.local-archive",
        qos: .utility,
        autoreleaseFrequency: .workItem
    )

    // Queue-confined state. These values are only read or mutated on `queue`.
    private static var pendingBatches: [Int64: VeilgramArchivePendingBatch] = [:]
    private static var flushScheduled = false
    private static var retryGenerationCounters: [Int64: Int] = [:]
    private static var activeRetryGenerations: [Int64: Int] = [:]
    private static let maximumMediaItemBytes: Int64 = 256 * 1024 * 1024
    private static let maximumMediaArchiveBytes: Int64 = 512 * 1024 * 1024

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
            var batch = pendingBatches[accountPeerId] ?? VeilgramArchivePendingBatch()
            batch.appendDeletedMessage(message, eligibility: eligibility)
            pendingBatches[accountPeerId] = batch

            if activeRetryGenerations[accountPeerId] != nil {
                return
            }
            if batch.eventCount >= VeilgramArchiveRuntimeBatchPolicy.maximumPendingEventsPerAccount {
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
            var batch = pendingBatches[accountPeerId] ?? VeilgramArchivePendingBatch()
            batch.appendEditRevision(
                key: key,
                revision: revision,
                eligibility: eligibility
            )
            pendingBatches[accountPeerId] = batch

            if activeRetryGenerations[accountPeerId] != nil {
                return
            }
            if batch.eventCount >= VeilgramArchiveRuntimeBatchPolicy.maximumPendingEventsPerAccount {
                flush(accountPeerId: accountPeerId)
            } else {
                scheduleFlushIfNeeded()
            }
        }
    }

    public static func enqueueLocalMediaCandidates(
        accountPeerId: Int64,
        candidates: [VeilgramLocalMediaArchiveCandidate],
        eligibility: VeilgramArchiveEligibility,
        completion: (() -> Void)? = nil
    ) {
        guard !candidates.isEmpty,
              VeilgramArchiveRuntimePreferences.messageArchiveEnabled(accountPeerId: accountPeerId),
              eligibility.isEligibleForLocalRetention else {
            if let completion {
                queue.async(execute: completion)
            }
            return
        }

        queue.async {
            defer {
                completion?()
            }
            do {
                let store = try VeilgramArchiveStoreAPI(accountId: accountPeerId)
                var document = try store.loadMedia()
                var changed = false

                for candidate in candidates {
                    if let existing = document.items.first(where: { $0.key == candidate.key }),
                       existing.availability == .available {
                        continue
                    }

                    guard let sourcePath = candidate.sourcePath else {
                        if try VeilgramMediaArchiveEngine.upsertUnavailable(
                            document: &document,
                            key: candidate.key,
                            archivedAt: candidate.archivedAt
                        ) {
                            changed = true
                        }
                        continue
                    }

                    do {
                        let copied = try store.copyMediaFile(
                            sourcePath: sourcePath,
                            key: candidate.key,
                            maximumBytes: maximumMediaItemBytes
                        )
                        let item = VeilgramMediaItem(
                            key: candidate.key,
                            relativePath: copied.relativePath,
                            byteCount: copied.byteCount,
                            archivedAt: candidate.archivedAt,
                            lastAccessedAt: candidate.archivedAt,
                            availability: .available
                        )
                        if try VeilgramMediaArchiveEngine.appendAvailable(
                            document: &document,
                            item: item,
                            eligibility: VeilgramMediaEligibility(
                                archiveEligibility: eligibility,
                                bytesAreLocallyAvailable: true
                            )
                        ) {
                            changed = true
                        }
                    } catch {
                        VeilgramArchiveRuntimeDiagnostics.record(error)
                        if try VeilgramMediaArchiveEngine.upsertUnavailable(
                            document: &document,
                            key: candidate.key,
                            archivedAt: candidate.archivedAt
                        ) {
                            changed = true
                        }
                    }
                }

                if changed {
                    let evicted = VeilgramMediaArchiveEngine.enforceQuota(
                        document: &document,
                        maximumBytes: maximumMediaArchiveBytes
                    )
                    for item in evicted {
                        if let relativePath = item.relativePath {
                            do {
                                try store.removeMediaFile(relativePath: relativePath)
                            } catch {
                                VeilgramArchiveRuntimeDiagnostics.record(error)
                            }
                        }
                    }
                    try store.saveMedia(document)
                }
            } catch {
                VeilgramArchiveRuntimeDiagnostics.record(error)
            }
        }
    }

    /// Requests an asynchronous flush on the same serial writer queue.
    /// Completion is delivered on the main queue after the immediate persistence
    /// attempt finishes. Failed persistence remains queued for bounded-backoff retry.
    public static func flushPending(completion: (() -> Void)? = nil) {
        queue.async {
            flushAll(force: true)
            completeOnMain(completion)
        }
    }

    /// Clears all Veilgram archive documents for one account on the writer queue.
    /// Pending pre-clear events are discarded so they cannot resurrect cleared data.
    public static func removeAll(
        accountPeerId: Int64,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async {
            do {
                let store = try VeilgramArchiveStoreAPI(accountId: accountPeerId)
                try store.removeAll()
                discardAllPending(accountPeerId: accountPeerId)
                completeOnMain {
                    completion(.success(()))
                }
            } catch {
                VeilgramArchiveRuntimeDiagnostics.record(error)
                completeOnMain {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Replaces the message archive on the writer queue. Pending message snapshots
    /// that predate the replacement are discarded by design; later events append
    /// normally after this mutation.
    public static func importMessages(
        accountPeerId: Int64,
        data: Data,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async {
            do {
                let store = try VeilgramArchiveStoreAPI(accountId: accountPeerId)
                try store.importMessages(data)
                discardPendingMessages(accountPeerId: accountPeerId)
                completeOnMain {
                    completion(.success(()))
                }
            } catch {
                VeilgramArchiveRuntimeDiagnostics.record(error)
                completeOnMain {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Replaces edit history on the writer queue. Pending revisions that predate
    /// the replacement are discarded by design.
    public static func importEdits(
        accountPeerId: Int64,
        data: Data,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async {
            do {
                let store = try VeilgramArchiveStoreAPI(accountId: accountPeerId)
                try store.importEdits(data)
                discardPendingEdits(accountPeerId: accountPeerId)
                completeOnMain {
                    completion(.success(()))
                }
            } catch {
                VeilgramArchiveRuntimeDiagnostics.record(error)
                completeOnMain {
                    completion(.failure(error))
                }
            }
        }
    }

    public static func importMediaMetadata(
        accountPeerId: Int64,
        data: Data,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async {
            do {
                let store = try VeilgramArchiveStoreAPI(accountId: accountPeerId)
                try store.importMediaMetadata(data)
                completeOnMain {
                    completion(.success(()))
                }
            } catch {
                VeilgramArchiveRuntimeDiagnostics.record(error)
                completeOnMain {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func scheduleFlushIfNeeded() {
        guard !flushScheduled else {
            return
        }
        flushScheduled = true
        queue.asyncAfter(
            deadline: .now() + .milliseconds(
                VeilgramArchiveRuntimeBatchPolicy.flushDelayMilliseconds
            )
        ) {
            flushScheduled = false
            flushAll(force: false)
        }
    }

    private static func flushAll(force: Bool) {
        let accountPeerIds = Array(pendingBatches.keys)
        for accountPeerId in accountPeerIds {
            if force {
                invalidateRetry(accountPeerId: accountPeerId)
                flush(accountPeerId: accountPeerId)
            } else if activeRetryGenerations[accountPeerId] == nil {
                flush(accountPeerId: accountPeerId)
            }
        }
    }

    private static func flush(accountPeerId: Int64) {
        guard let batch = pendingBatches.removeValue(forKey: accountPeerId) else {
            return
        }

        let store: VeilgramArchiveStoreAPI
        do {
            store = try VeilgramArchiveStoreAPI(accountId: accountPeerId)
        } catch {
            VeilgramArchiveRuntimeDiagnostics.record(error)
            var retryBatch = batch
            retryBatch.retryAttempt += 1
            requeueForRetry(accountPeerId: accountPeerId, batch: retryBatch)
            return
        }

        var retryBatch = VeilgramArchivePendingBatch()
        let nextRetryAttempt = batch.retryAttempt + 1

        if !batch.deletedMessageOrder.isEmpty {
            if !flushDeletedMessages(batch, store: store) {
                retryBatch.mergeNewer(
                    batch.deletedMessagesOnly(nextRetryAttempt: nextRetryAttempt)
                )
            }
        }

        if !batch.editRevisions.isEmpty {
            if !flushEditRevisions(batch, store: store) {
                retryBatch.mergeNewer(
                    batch.editRevisionsOnly(nextRetryAttempt: nextRetryAttempt)
                )
            }
        }

        if !retryBatch.isEmpty {
            requeueForRetry(accountPeerId: accountPeerId, batch: retryBatch)
        }
    }

    /// Returns false only for document-level load/save failures that should be retried.
    /// Invalid individual events are diagnosed and skipped rather than poisoning a batch.
    private static func flushDeletedMessages(
        _ batch: VeilgramArchivePendingBatch,
        store: VeilgramArchiveStoreAPI
    ) -> Bool {
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
            return true
        } catch {
            VeilgramArchiveRuntimeDiagnostics.record(error)
            return false
        }
    }

    /// Returns false only for document-level load/save failures that should be retried.
    private static func flushEditRevisions(
        _ batch: VeilgramArchivePendingBatch,
        store: VeilgramArchiveStoreAPI
    ) -> Bool {
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
            return true
        } catch {
            VeilgramArchiveRuntimeDiagnostics.record(error)
            return false
        }
    }

    private static func requeueForRetry(
        accountPeerId: Int64,
        batch: VeilgramArchivePendingBatch
    ) {
        var requeuedBatch = batch
        if let newerBatch = pendingBatches.removeValue(forKey: accountPeerId) {
            requeuedBatch.mergeNewer(newerBatch)
        }
        if requeuedBatch.retryAttempt == 0 {
            requeuedBatch.retryAttempt = 1
        }
        pendingBatches[accountPeerId] = requeuedBatch

        let generation = (retryGenerationCounters[accountPeerId] ?? 0) + 1
        retryGenerationCounters[accountPeerId] = generation
        activeRetryGenerations[accountPeerId] = generation

        let delay = VeilgramArchiveRuntimeBatchPolicy.retryDelayMilliseconds(
            attempt: requeuedBatch.retryAttempt
        )
        queue.asyncAfter(deadline: .now() + .milliseconds(delay)) {
            guard activeRetryGenerations[accountPeerId] == generation else {
                return
            }
            activeRetryGenerations.removeValue(forKey: accountPeerId)
            flush(accountPeerId: accountPeerId)
        }
    }

    private static func discardPendingMessages(accountPeerId: Int64) {
        guard var batch = pendingBatches[accountPeerId] else {
            return
        }
        batch.discardDeletedMessages()
        updatePendingBatchAfterMutation(accountPeerId: accountPeerId, batch: batch)
    }

    private static func discardPendingEdits(accountPeerId: Int64) {
        guard var batch = pendingBatches[accountPeerId] else {
            return
        }
        batch.discardEditRevisions()
        updatePendingBatchAfterMutation(accountPeerId: accountPeerId, batch: batch)
    }

    private static func discardAllPending(accountPeerId: Int64) {
        pendingBatches.removeValue(forKey: accountPeerId)
        invalidateRetry(accountPeerId: accountPeerId)
    }

    private static func updatePendingBatchAfterMutation(
        accountPeerId: Int64,
        batch: VeilgramArchivePendingBatch
    ) {
        if batch.isEmpty {
            pendingBatches.removeValue(forKey: accountPeerId)
            invalidateRetry(accountPeerId: accountPeerId)
        } else {
            pendingBatches[accountPeerId] = batch
        }
    }

    private static func invalidateRetry(accountPeerId: Int64) {
        retryGenerationCounters[accountPeerId] = (retryGenerationCounters[accountPeerId] ?? 0) + 1
        activeRetryGenerations.removeValue(forKey: accountPeerId)
    }

    private static func completeOnMain(_ completion: (() -> Void)?) {
        guard let completion else {
            return
        }
        DispatchQueue.main.async(execute: completion)
    }
}
