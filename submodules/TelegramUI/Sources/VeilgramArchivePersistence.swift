import Foundation

struct VeilgramArchivePersistence {
    static let messageArchiveFileName = "message-archive-v1.json"
    static let editHistoryFileName = "edit-history-v1.json"
    static let mediaArchiveFileName = "media-archive-v1.json"

    let store: VeilgramProtectedLocalStore

    static func accountStore(accountId: Int64) throws -> VeilgramArchivePersistence {
        return VeilgramArchivePersistence(
            store: try VeilgramProtectedLocalStore.accountStore(accountId: accountId)
        )
    }

    func saveMessageArchive(_ document: VeilgramMessageArchiveDocument) throws {
        let data = try VeilgramMessageArchiveEngine.encode(document)
        try store.write(data, fileName: Self.messageArchiveFileName)
    }

    func loadMessageArchive() throws -> VeilgramMessageArchiveDocument {
        guard let data = try store.read(fileName: Self.messageArchiveFileName) else {
            return VeilgramMessageArchiveDocument()
        }
        return try VeilgramMessageArchiveEngine.decode(data)
    }

    func saveEditHistory(_ document: VeilgramEditHistoryDocument) throws {
        let data = try VeilgramEditHistoryEngine.encode(document)
        try store.write(data, fileName: Self.editHistoryFileName)
    }

    func loadEditHistory() throws -> VeilgramEditHistoryDocument {
        guard let data = try store.read(fileName: Self.editHistoryFileName) else {
            return VeilgramEditHistoryDocument()
        }
        return try VeilgramEditHistoryEngine.decode(data)
    }

    func saveMediaArchive(_ document: VeilgramMediaArchiveDocument) throws {
        let data = try VeilgramMediaArchiveEngine.encode(document)
        try store.write(data, fileName: Self.mediaArchiveFileName)
    }

    func loadMediaArchive() throws -> VeilgramMediaArchiveDocument {
        guard let data = try store.read(fileName: Self.mediaArchiveFileName) else {
            return VeilgramMediaArchiveDocument()
        }
        return try VeilgramMediaArchiveEngine.decode(data)
    }

    func removeAllLocalArchiveData() throws {
        try store.remove(fileName: Self.messageArchiveFileName)
        try store.remove(fileName: Self.editHistoryFileName)
        try store.remove(fileName: Self.mediaArchiveFileName)
    }
}
