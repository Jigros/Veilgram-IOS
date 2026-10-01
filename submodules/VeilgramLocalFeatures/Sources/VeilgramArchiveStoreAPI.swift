import Foundation

public struct VeilgramArchiveStoreAPI {
    private static let messageFile = "message-archive-v1.json"
    private static let editFile = "edit-history-v1.json"
    private static let mediaFile = "media-archive-v1.json"
    private static let mediaBinaryPrefix = "media-"

    private let store: VeilgramProtectedLocalStore
    private let accountId: Int64?

    public init(accountId: Int64) throws {
        self.store = try VeilgramProtectedLocalStore.accountStore(accountId: accountId)
        self.accountId = accountId
    }

    init(store: VeilgramProtectedLocalStore) {
        self.store = store
        self.accountId = nil
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
        if let accountId = self.accountId {
            VeilgramArchiveRuntimeIndex.replaceEditDocument(
                accountId: accountId,
                document: document
            )
        }
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

    func copyMediaFile(
        sourcePath: String,
        key: VeilgramMediaKey,
        maximumBytes: Int64
    ) throws -> (relativePath: String, byteCount: Int64) {
        let fileName = Self.mediaFileName(key)
        let byteCount = try store.copyFile(
            from: URL(fileURLWithPath: sourcePath),
            fileName: fileName,
            maximumBytes: maximumBytes
        )
        return (fileName, byteCount)
    }

    func removeMediaFile(relativePath: String) throws {
        try store.remove(fileName: relativePath)
    }

    private static func mediaFileName(_ key: VeilgramMediaKey) -> String {
        return "\(mediaBinaryPrefix)\(key.peerId)-\(key.messageNamespace)-\(key.messageId)-\(key.mediaIndex).bin"
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
        let imported = try VeilgramMediaArchiveEngine.decode(payload)
        let metadataOnlyItems = imported.items.map { item -> VeilgramMediaItem in
            guard item.availability == .available else {
                return item
            }
            return VeilgramMediaItem(
                key: item.key,
                relativePath: nil,
                byteCount: 0,
                archivedAt: item.archivedAt,
                lastAccessedAt: item.lastAccessedAt,
                availability: .unavailable
            )
        }
        let metadataOnlyDocument = VeilgramMediaArchiveDocument(
            version: imported.version,
            items: metadataOnlyItems
        )
        _ = try VeilgramMediaArchiveEngine.encode(metadataOnlyDocument)

        try store.removeFiles(withPrefix: Self.mediaBinaryPrefix)
        try saveMedia(metadataOnlyDocument)
    }

    public func removeAll() throws {
        try store.remove(fileName: Self.messageFile)
        try store.remove(fileName: Self.editFile)
        try store.remove(fileName: Self.mediaFile)
        try store.removeFiles(withPrefix: Self.mediaBinaryPrefix)
        if let accountId = self.accountId {
            VeilgramArchiveRuntimeIndex.invalidateEdits(accountId: accountId)
        }
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
