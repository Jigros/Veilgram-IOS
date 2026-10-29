import Foundation

public enum VeilgramArchiveRuntimeIndex {
    private static let lock = NSLock()
    private static var loadedEditAccounts = Set<Int64>()
    private static var editsByAccount: [Int64: [VeilgramMessageKey: [VeilgramEditRevision]]] = [:]

    private static func makeEditMap(
        _ document: VeilgramEditHistoryDocument
    ) -> [VeilgramMessageKey: [VeilgramEditRevision]] {
        var result: [VeilgramMessageKey: [VeilgramEditRevision]] = [:]
        for record in document.records {
            result[record.message] = record.revisions
        }
        return result
    }

    private static func ensureEditsLoaded(accountId: Int64) {
        lock.lock()
        let alreadyLoaded = loadedEditAccounts.contains(accountId)
        lock.unlock()
        if alreadyLoaded {
            return
        }

        let loadedDocument: VeilgramEditHistoryDocument
        do {
            let store = try VeilgramArchiveStoreAPI(accountId: accountId)
            loadedDocument = try store.loadEdits()
        } catch {
            loadedDocument = VeilgramEditHistoryDocument()
        }
        let mapped = makeEditMap(loadedDocument)

        lock.lock()
        if !loadedEditAccounts.contains(accountId) {
            editsByAccount[accountId] = mapped
            loadedEditAccounts.insert(accountId)
        }
        lock.unlock()
    }

    public static func editRevisions(
        accountId: Int64,
        key: VeilgramMessageKey
    ) -> [VeilgramEditRevision] {
        ensureEditsLoaded(accountId: accountId)
        lock.lock()
        let result = editsByAccount[accountId]?[key] ?? []
        lock.unlock()
        return result
    }

    public static func editRevisionCount(
        accountId: Int64,
        key: VeilgramMessageKey
    ) -> Int {
        return editRevisions(accountId: accountId, key: key).count
    }

    static func appendEditRevision(
        accountId: Int64,
        key: VeilgramMessageKey,
        revision: VeilgramEditRevision
    ) {
        ensureEditsLoaded(accountId: accountId)
        lock.lock()
        var accountEdits = editsByAccount[accountId] ?? [:]
        var revisions = accountEdits[key] ?? []
        if revisions.last != revision {
            revisions.append(revision)
            if revisions.count > VeilgramEditHistoryEngine.maximumRevisionsPerMessage {
                revisions.removeFirst(revisions.count - VeilgramEditHistoryEngine.maximumRevisionsPerMessage)
            }
            accountEdits[key] = revisions
            editsByAccount[accountId] = accountEdits
        }
        loadedEditAccounts.insert(accountId)
        lock.unlock()
    }

    static func replaceEditDocument(
        accountId: Int64,
        document: VeilgramEditHistoryDocument
    ) {
        let mapped = makeEditMap(document)
        lock.lock()
        editsByAccount[accountId] = mapped
        loadedEditAccounts.insert(accountId)
        lock.unlock()
    }

    public static func invalidateEdits(accountId: Int64) {
        lock.lock()
        editsByAccount.removeValue(forKey: accountId)
        loadedEditAccounts.remove(accountId)
        lock.unlock()
    }
}
