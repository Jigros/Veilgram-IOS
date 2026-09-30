import Foundation

public struct VeilgramArchiveStoreAPI {
    private static let messageFile = "message-archive-v1.json"
    private static let editFile = "edit-history-v1.json"
    private static let mediaFile = "media-archive-v1.json"

    private let store: VeilgramProtectedLocalStore

    public init(accountId: Int64) throws {
        self.store = try VeilgramProtectedLocalStore.accountStore(accountId: accountId)
    }

    init(store: VeilgramProtectedLocalStore) {
        self.store = store
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

    public func exportMessages(createdAt: Int32) throws -> Data {
        return try Self.exportEnvelope(
            kind: .messageArchive,
            createdAt: createdAt,
            payload: VeilgramMessageArchiveEngine.encode(try loadMessages())
        )
    }

    public func exportEdits(createdAt: Int32) throws -> Data {
        return try Self.exportEnvelope(
            kind: .editHistory,
            createdAt: createdAt,
            payload: VeilgramEditHistoryEngine.encode(try loadEdits())
        )
    }

    public func exportMediaMetadata(createdAt: Int32) throws -> Data {
        return try Self.exportEnvelope(
            kind: .mediaArchiveMetadata,
            createdAt: createdAt,
            payload: VeilgramMediaArchiveEngine.encode(try loadMedia())
        )
    }

    public func importMessages(_ data: Data) throws {
        let payload = try Self.importPayload(data, expectedKind: .messageArchive)
        try saveMessages(VeilgramMessageArchiveEngine.decode(payload))
    }

    public func importEdits(_ data: Data) throws {
        let payload = try Self.importPayload(data, expectedKind: .editHistory)
        try saveEdits(VeilgramEditHistoryEngine.decode(payload))
    }

    public func importMediaMetadata(_ data: Data) throws {
        let payload = try Self.importPayload(data, expectedKind: .mediaArchiveMetadata)
        try saveMedia(VeilgramMediaArchiveEngine.decode(payload))
    }

    public func removeAll() throws {
        try store.remove(fileName: Self.messageFile)
        try store.remove(fileName: Self.editFile)
        try store.remove(fileName: Self.mediaFile)
    }

    private static func exportEnvelope(
        kind: VeilgramTransferKind,
        createdAt: Int32,
        payload: Data
    ) throws -> Data {
        return try VeilgramTransferEngine.encode(
            VeilgramTransferEngine.makeEnvelope(
                kind: kind,
                createdAt: createdAt,
                payload: payload
            )
        )
    }

    private static func importPayload(
        _ data: Data,
        expectedKind: VeilgramTransferKind
    ) throws -> Data {
        let envelope = try VeilgramTransferEngine.decode(data)
        guard envelope.kind == expectedKind else {
            throw VeilgramTransferError.invalidDocument
        }
        return envelope.payload
    }
}
