import Foundation

struct VeilgramMessageFilterPersistence {
    static let fileName = "message-filters-v1.json"

    let store: VeilgramProtectedLocalStore

    static func accountStore(accountId: Int64) throws -> VeilgramMessageFilterPersistence {
        return VeilgramMessageFilterPersistence(
            store: try VeilgramProtectedLocalStore.accountStore(accountId: accountId)
        )
    }

    func save(_ document: VeilgramMessageFilterDocument) throws {
        let data = try VeilgramMessageFilterEngine.encode(document)
        try store.write(data, fileName: Self.fileName)
    }

    func load() throws -> VeilgramMessageFilterDocument {
        guard let data = try store.read(fileName: Self.fileName) else {
            return VeilgramMessageFilterDocument(rules: [])
        }
        return try VeilgramMessageFilterEngine.decode(data)
    }

    func removeAll() throws {
        try store.remove(fileName: Self.fileName)
    }

    func exportEnvelope(
        document: VeilgramMessageFilterDocument,
        createdAt: Int32
    ) throws -> Data {
        let payload = try VeilgramMessageFilterEngine.encode(document)
        let envelope = try VeilgramTransferEngine.makeEnvelope(
            kind: .filters,
            createdAt: createdAt,
            payload: payload
        )
        return try VeilgramTransferEngine.encode(envelope)
    }

    func importEnvelope(_ data: Data) throws -> VeilgramMessageFilterDocument {
        let envelope = try VeilgramTransferEngine.decode(data)
        guard envelope.kind == .filters else {
            throw VeilgramTransferError.invalidDocument
        }
        return try VeilgramMessageFilterEngine.decode(envelope.payload)
    }

    func importAndSave(_ data: Data) throws -> VeilgramMessageFilterDocument {
        let document = try importEnvelope(data)
        try save(document)
        return document
    }
}
