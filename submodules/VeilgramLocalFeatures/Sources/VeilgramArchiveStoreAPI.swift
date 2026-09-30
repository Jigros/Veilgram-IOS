import Foundation

public struct VeilgramArchiveStoreAPI {
    private static let messageFile = "message-archive-v1.json"
    private static let editFile = "edit-history-v1.json"
    private static let mediaFile = "media-archive-v1.json"

    private let store: VeilgramProtectedLocalStore

    public init(accountId: Int64) throws {
        self.store = try VeilgramProtectedLocalStore.accountStore(accountId: accountId)
    }

    public func loadMessages() throws -> VeilgramMessageArchiveDocument {
        guard let data = try store.read(fileName: Self.messageFile) else {
            return VeilgramMessageArchiveDocument()
        }
        return try VeilgramMessageArchiveEngine.decode(data)
    }

    public func saveMessages(_ document: VeilgramMessageArchiveDocument) throws {
        try store.write(try VeilgramMessageArchiveEngine.encode(document), fileName: Self.messageFile)
    }

    public func loadEdits() throws -> VeilgramEditHistoryDocument {
        guard let data = try store.read(fileName: Self.editFile) else {
            return VeilgramEditHistoryDocument()
        }
        return try VeilgramEditHistoryEngine.decode(data)
    }

    public func saveEdits(_ document: VeilgramEditHistoryDocument) throws {
        try store.write(try VeilgramEditHistoryEngine.encode(document), fileName: Self.editFile)
    }

    public func loadMedia() throws -> VeilgramMediaArchiveDocument {
        guard let data = try store.read(fileName: Self.mediaFile) else {
            return VeilgramMediaArchiveDocument()
        }
        return try VeilgramMediaArchiveEngine.decode(data)
    }

    public func saveMedia(_ document: VeilgramMediaArchiveDocument) throws {
        try store.write(try VeilgramMediaArchiveEngine.encode(document), fileName: Self.mediaFile)
    }

    public func removeAll() throws {
        try store.remove(fileName: Self.messageFile)
        try store.remove(fileName: Self.editFile)
        try store.remove(fileName: Self.mediaFile)
    }
}
