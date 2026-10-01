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
    private static let queue = DispatchQueue(label: "org.veilgram.local-archive")

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
            do {
                let store = try VeilgramArchiveStoreAPI(accountId: accountPeerId)
                var document = try store.loadMessages()
                if try VeilgramMessageArchiveEngine.append(
                    document: &document,
                    message: message,
                    eligibility: eligibility
                ) {
                    try store.saveMessages(document)
                }
            } catch {
                VeilgramArchiveRuntimeDiagnostics.record(error)
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

        VeilgramArchiveRuntimeIndex.appendEditRevision(
            accountId: accountPeerId,
            key: key,
            revision: revision
        )

        queue.async {
            do {
                let store = try VeilgramArchiveStoreAPI(accountId: accountPeerId)
                var document = try store.loadEdits()
                if try VeilgramEditHistoryEngine.append(
                    document: &document,
                    key: key,
                    revision: revision,
                    eligibility: eligibility
                ) {
                    try store.saveEdits(document)
                    VeilgramArchiveRuntimeIndex.replaceEditDocument(
                        accountId: accountPeerId,
                        document: document
                    )
                }
            } catch {
                VeilgramArchiveRuntimeDiagnostics.record(error)
            }
        }
    }
}