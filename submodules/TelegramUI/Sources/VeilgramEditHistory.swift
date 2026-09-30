import Foundation

struct VeilgramEditHistoryMessageKey: Codable, Hashable, Equatable {
    var peerId: Int64
    var namespace: Int32
    var id: Int32
}

struct VeilgramEditHistoryEntity: Codable, Equatable {
    var offset: Int
    var length: Int
    var kind: String
}

struct VeilgramEditHistoryRevision: Codable, Equatable {
    var timestamp: Int32
    var text: String
    var entities: [VeilgramEditHistoryEntity]
}

struct VeilgramEditHistoryRecord: Codable, Equatable {
    var message: VeilgramEditHistoryMessageKey
    var revisions: [VeilgramEditHistoryRevision]
}

struct VeilgramEditHistoryDocument: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = currentVersion
    var records: [VeilgramEditHistoryRecord] = []
}

struct VeilgramEditHistoryEligibility {
    var isCloudMessage: Bool
    var isSecretChat: Bool
    var isViewOnce: Bool
    var hasSelfDestructTimeout: Bool
}

enum VeilgramEditHistoryError: Error, Equatable {
    case unsupportedVersion
    case documentTooLarge
    case tooManyRecords
    case tooManyRevisions
    case textTooLong
    case invalidEntity
}

/// Local revision model only. This type deliberately has no Telegram network,
/// update interception or filesystem code. Integration must call the
/// eligibility gate before retaining any previous message revision.
enum VeilgramEditHistoryEngine {
    static let maximumDocumentBytes = 8 * 1024 * 1024
    static let maximumRecords = 5_000
    static let maximumRevisionsPerMessage = 32
    static let maximumTextCharacters = 16_000
    static let maximumEntitiesPerRevision = 512

    static func isEligible(_ value: VeilgramEditHistoryEligibility) -> Bool {
        return value.isCloudMessage
            && !value.isSecretChat
            && !value.isViewOnce
            && !value.hasSelfDestructTimeout
    }

    static func append(
        document: inout VeilgramEditHistoryDocument,
        key: VeilgramEditHistoryMessageKey,
        revision: VeilgramEditHistoryRevision,
        eligibility: VeilgramEditHistoryEligibility
    ) throws -> Bool {
        guard isEligible(eligibility) else {
            return false
        }
        try validate(revision)

        if let index = document.records.firstIndex(where: { $0.message == key }) {
            if document.records[index].revisions.last == revision {
                return false
            }
            document.records[index].revisions.append(revision)
            if document.records[index].revisions.count > maximumRevisionsPerMessage {
                document.records[index].revisions.removeFirst(
                    document.records[index].revisions.count - maximumRevisionsPerMessage
                )
            }
        } else {
            guard document.records.count < maximumRecords else {
                throw VeilgramEditHistoryError.tooManyRecords
            }
            document.records.append(
                VeilgramEditHistoryRecord(message: key, revisions: [revision])
            )
        }
        return true
    }

    static func validate(_ revision: VeilgramEditHistoryRevision) throws {
        guard revision.text.count <= maximumTextCharacters else {
            throw VeilgramEditHistoryError.textTooLong
        }
        guard revision.entities.count <= maximumEntitiesPerRevision else {
            throw VeilgramEditHistoryError.invalidEntity
        }
        for entity in revision.entities {
            guard entity.offset >= 0,
                  entity.length >= 0,
                  entity.offset + entity.length <= revision.text.utf16.count,
                  !entity.kind.isEmpty,
                  entity.kind.count <= 64 else {
                throw VeilgramEditHistoryError.invalidEntity
            }
        }
    }

    static func encode(_ document: VeilgramEditHistoryDocument) throws -> Data {
        guard document.version == VeilgramEditHistoryDocument.currentVersion else {
            throw VeilgramEditHistoryError.unsupportedVersion
        }
        guard document.records.count <= maximumRecords else {
            throw VeilgramEditHistoryError.tooManyRecords
        }
        for record in document.records {
            guard record.revisions.count <= maximumRevisionsPerMessage else {
                throw VeilgramEditHistoryError.tooManyRevisions
            }
            for revision in record.revisions {
                try validate(revision)
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramEditHistoryError.documentTooLarge
        }
        return data
    }

    static func decode(_ data: Data) throws -> VeilgramEditHistoryDocument {
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramEditHistoryError.documentTooLarge
        }
        let document = try JSONDecoder().decode(VeilgramEditHistoryDocument.self, from: data)
        _ = try encode(document)
        return document
    }
}
