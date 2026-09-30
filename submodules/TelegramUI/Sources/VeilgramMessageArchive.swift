import Foundation

struct VeilgramArchivedMessageKey: Codable, Hashable, Equatable {
    var peerId: Int64
    var namespace: Int32
    var id: Int32
}

struct VeilgramArchivedMessageEntity: Codable, Equatable {
    var offset: Int
    var length: Int
    var kind: String
}

struct VeilgramArchivedMessage: Codable, Equatable {
    var key: VeilgramArchivedMessageKey
    var messageTimestamp: Int32
    var archivedAt: Int32
    var text: String
    var entities: [VeilgramArchivedMessageEntity]
    var hadMedia: Bool
}

struct VeilgramMessageArchiveDocument: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = currentVersion
    var messages: [VeilgramArchivedMessage] = []
}

struct VeilgramMessageArchiveEligibility {
    var isCloudMessage: Bool
    var isSecretChat: Bool
    var isViewOnce: Bool
    var hasSelfDestructTimeout: Bool
}

enum VeilgramMessageArchiveError: Error, Equatable {
    case unsupportedVersion
    case documentTooLarge
    case tooManyMessages
    case textTooLong
    case invalidEntity
}

/// Storage-model core only. No Telegram update interception or Postbox writes.
/// Integration must pass the eligibility gate before adding snapshots.
enum VeilgramMessageArchiveEngine {
    static let maximumDocumentBytes = 32 * 1024 * 1024
    static let maximumMessages = 10_000
    static let maximumTextCharacters = 16_000
    static let maximumEntitiesPerMessage = 512

    static func isEligible(_ value: VeilgramMessageArchiveEligibility) -> Bool {
        return value.isCloudMessage
            && !value.isSecretChat
            && !value.isViewOnce
            && !value.hasSelfDestructTimeout
    }

    static func validate(_ message: VeilgramArchivedMessage) throws {
        guard message.text.count <= maximumTextCharacters else {
            throw VeilgramMessageArchiveError.textTooLong
        }
        guard message.entities.count <= maximumEntitiesPerMessage else {
            throw VeilgramMessageArchiveError.invalidEntity
        }
        for entity in message.entities {
            guard entity.offset >= 0,
                  entity.length >= 0,
                  entity.offset + entity.length <= message.text.utf16.count,
                  !entity.kind.isEmpty,
                  entity.kind.count <= 64 else {
                throw VeilgramMessageArchiveError.invalidEntity
            }
        }
    }

    @discardableResult
    static func append(
        document: inout VeilgramMessageArchiveDocument,
        message: VeilgramArchivedMessage,
        eligibility: VeilgramMessageArchiveEligibility
    ) throws -> Bool {
        guard isEligible(eligibility) else {
            return false
        }
        try validate(message)

        if let index = document.messages.firstIndex(where: { $0.key == message.key }) {
            if document.messages[index] == message {
                return false
            }
            document.messages[index] = message
            return true
        }

        guard document.messages.count < maximumMessages else {
            throw VeilgramMessageArchiveError.tooManyMessages
        }
        document.messages.append(message)
        return true
    }

    static func prune(
        document: inout VeilgramMessageArchiveDocument,
        now: Int32,
        retentionSeconds: Int32
    ) {
        guard retentionSeconds > 0 else {
            document.messages.removeAll()
            return
        }
        let cutoff = now > retentionSeconds ? now - retentionSeconds : 0
        document.messages.removeAll(where: { $0.archivedAt < cutoff })
    }

    static func remove(
        document: inout VeilgramMessageArchiveDocument,
        key: VeilgramArchivedMessageKey
    ) {
        document.messages.removeAll(where: { $0.key == key })
    }

    static func encode(_ document: VeilgramMessageArchiveDocument) throws -> Data {
        guard document.version == VeilgramMessageArchiveDocument.currentVersion else {
            throw VeilgramMessageArchiveError.unsupportedVersion
        }
        guard document.messages.count <= maximumMessages else {
            throw VeilgramMessageArchiveError.tooManyMessages
        }
        for message in document.messages {
            try validate(message)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramMessageArchiveError.documentTooLarge
        }
        return data
    }

    static func decode(_ data: Data) throws -> VeilgramMessageArchiveDocument {
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramMessageArchiveError.documentTooLarge
        }
        let document = try JSONDecoder().decode(VeilgramMessageArchiveDocument.self, from: data)
        _ = try encode(document)
        return document
    }
}
