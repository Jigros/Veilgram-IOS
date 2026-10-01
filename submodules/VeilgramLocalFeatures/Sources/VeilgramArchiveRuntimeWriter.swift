import Foundation

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
            }
        }
    }
}
