import Foundation

public struct VeilgramMessageKey: Codable, Hashable, Equatable {
    public var peerId: Int64
    public var namespace: Int32
    public var id: Int32

    public init(peerId: Int64, namespace: Int32, id: Int32) {
        self.peerId = peerId
        self.namespace = namespace
        self.id = id
    }
}

public struct VeilgramTextEntity: Codable, Equatable {
    public var offset: Int
    public var length: Int
    public var kind: String

    public init(offset: Int, length: Int, kind: String) {
        self.offset = offset
        self.length = length
        self.kind = kind
    }
}

public struct VeilgramArchiveEligibility: Equatable {
    public var isCloudMessage: Bool
    public var isSecretChat: Bool
    public var isViewOnce: Bool
    public var hasSelfDestructTimeout: Bool

    public init(
        isCloudMessage: Bool,
        isSecretChat: Bool,
        isViewOnce: Bool,
        hasSelfDestructTimeout: Bool
    ) {
        self.isCloudMessage = isCloudMessage
        self.isSecretChat = isSecretChat
        self.isViewOnce = isViewOnce
        self.hasSelfDestructTimeout = hasSelfDestructTimeout
    }

    public var isEligibleForLocalRetention: Bool {
        return isCloudMessage && !isSecretChat && !isViewOnce && !hasSelfDestructTimeout
    }
}

public struct VeilgramArchivedMessage: Codable, Equatable {
    public var key: VeilgramMessageKey
    public var messageTimestamp: Int32
    public var archivedAt: Int32
    public var text: String
    public var entities: [VeilgramTextEntity]
    public var hadMedia: Bool

    public init(
        key: VeilgramMessageKey,
        messageTimestamp: Int32,
        archivedAt: Int32,
        text: String,
        entities: [VeilgramTextEntity],
        hadMedia: Bool
    ) {
        self.key = key
        self.messageTimestamp = messageTimestamp
        self.archivedAt = archivedAt
        self.text = text
        self.entities = entities
        self.hadMedia = hadMedia
    }
}

public struct VeilgramMessageArchiveDocument: Codable, Equatable {
    public static let currentVersion = 1
    public var version: Int
    public var messages: [VeilgramArchivedMessage]

    public init(version: Int = currentVersion, messages: [VeilgramArchivedMessage] = []) {
        self.version = version
        self.messages = messages
    }
}

public enum VeilgramMessageArchiveError: Error, Equatable {
    case unsupportedVersion
    case documentTooLarge
    case tooManyMessages
    case textTooLong
    case invalidEntity
}

public enum VeilgramMessageArchiveEngine {
    public static let maximumDocumentBytes = 32 * 1024 * 1024
    public static let maximumMessages = 10_000
    public static let maximumTextCharacters = 16_000
    public static let maximumEntitiesPerMessage = 512

    public static func isEligible(_ value: VeilgramArchiveEligibility) -> Bool {
        return value.isEligibleForLocalRetention
    }

    public static func validate(_ message: VeilgramArchivedMessage) throws {
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
    public static func append(
        document: inout VeilgramMessageArchiveDocument,
        message: VeilgramArchivedMessage,
        eligibility: VeilgramArchiveEligibility
    ) throws -> Bool {
        guard isEligible(eligibility) else { return false }
        try validate(message)
        if let index = document.messages.firstIndex(where: { $0.key == message.key }) {
            guard document.messages[index] != message else { return false }
            document.messages[index] = message
            return true
        }
        if document.messages.count >= maximumMessages {
            document.messages.sort { lhs, rhs in
                if lhs.archivedAt != rhs.archivedAt {
                    return lhs.archivedAt < rhs.archivedAt
                }
                return lhs.messageTimestamp < rhs.messageTimestamp
            }
            document.messages.removeFirst(document.messages.count - maximumMessages + 1)
        }
        document.messages.append(message)
        return true
    }

    public static func prune(
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

    public static func encode(_ document: VeilgramMessageArchiveDocument) throws -> Data {
        guard document.version == VeilgramMessageArchiveDocument.currentVersion else {
            throw VeilgramMessageArchiveError.unsupportedVersion
        }
        guard document.messages.count <= maximumMessages else {
            throw VeilgramMessageArchiveError.tooManyMessages
        }
        for message in document.messages { try validate(message) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramMessageArchiveError.documentTooLarge
        }
        return data
    }

    public static func decode(_ data: Data) throws -> VeilgramMessageArchiveDocument {
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramMessageArchiveError.documentTooLarge
        }
        let document = try JSONDecoder().decode(VeilgramMessageArchiveDocument.self, from: data)
        _ = try encode(document)
        return document
    }
}

public struct VeilgramEditRevision: Codable, Equatable {
    public var timestamp: Int32
    public var text: String
    public var entities: [VeilgramTextEntity]

    public init(timestamp: Int32, text: String, entities: [VeilgramTextEntity]) {
        self.timestamp = timestamp
        self.text = text
        self.entities = entities
    }
}

public struct VeilgramEditHistoryRecord: Codable, Equatable {
    public var message: VeilgramMessageKey
    public var revisions: [VeilgramEditRevision]

    public init(message: VeilgramMessageKey, revisions: [VeilgramEditRevision]) {
        self.message = message
        self.revisions = revisions
    }
}

public struct VeilgramEditHistoryDocument: Codable, Equatable {
    public static let currentVersion = 1
    public var version: Int
    public var records: [VeilgramEditHistoryRecord]

    public init(version: Int = currentVersion, records: [VeilgramEditHistoryRecord] = []) {
        self.version = version
        self.records = records
    }
}

public enum VeilgramEditHistoryError: Error, Equatable {
    case unsupportedVersion
    case documentTooLarge
    case tooManyRecords
    case tooManyRevisions
    case textTooLong
    case invalidEntity
}

public enum VeilgramEditHistoryEngine {
    public static let maximumDocumentBytes = 8 * 1024 * 1024
    public static let maximumRecords = 5_000
    public static let maximumRevisionsPerMessage = 32
    public static let maximumTextCharacters = 16_000
    public static let maximumEntitiesPerRevision = 512

    public static func validate(_ revision: VeilgramEditRevision) throws {
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

    @discardableResult
    public static func append(
        document: inout VeilgramEditHistoryDocument,
        key: VeilgramMessageKey,
        revision: VeilgramEditRevision,
        eligibility: VeilgramArchiveEligibility
    ) throws -> Bool {
        guard eligibility.isEligibleForLocalRetention else { return false }
        try validate(revision)
        if let index = document.records.firstIndex(where: { $0.message == key }) {
            guard document.records[index].revisions.last != revision else { return false }
            document.records[index].revisions.append(revision)
            if document.records[index].revisions.count > maximumRevisionsPerMessage {
                document.records[index].revisions.removeFirst(
                    document.records[index].revisions.count - maximumRevisionsPerMessage
                )
            }
        } else {
            if document.records.count >= maximumRecords {
                document.records.sort { lhs, rhs in
                    let lhsTimestamp = lhs.revisions.last?.timestamp ?? Int32.min
                    let rhsTimestamp = rhs.revisions.last?.timestamp ?? Int32.min
                    return lhsTimestamp < rhsTimestamp
                }
                document.records.removeFirst(document.records.count - maximumRecords + 1)
            }
            document.records.append(VeilgramEditHistoryRecord(message: key, revisions: [revision]))
        }
        return true
    }

    public static func encode(_ document: VeilgramEditHistoryDocument) throws -> Data {
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
            for revision in record.revisions { try validate(revision) }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramEditHistoryError.documentTooLarge
        }
        return data
    }

    public static func decode(_ data: Data) throws -> VeilgramEditHistoryDocument {
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramEditHistoryError.documentTooLarge
        }
        let document = try JSONDecoder().decode(VeilgramEditHistoryDocument.self, from: data)
        _ = try encode(document)
        return document
    }
}

public struct VeilgramMediaKey: Codable, Hashable, Equatable {
    public var peerId: Int64
    public var messageNamespace: Int32
    public var messageId: Int32
    public var mediaIndex: Int

    public init(peerId: Int64, messageNamespace: Int32, messageId: Int32, mediaIndex: Int) {
        self.peerId = peerId
        self.messageNamespace = messageNamespace
        self.messageId = messageId
        self.mediaIndex = mediaIndex
    }
}

public enum VeilgramMediaAvailability: String, Codable, Equatable {
    case available
    case unavailable
}

public struct VeilgramMediaItem: Codable, Equatable {
    public var key: VeilgramMediaKey
    public var relativePath: String?
    public var byteCount: Int64
    public var archivedAt: Int32
    public var lastAccessedAt: Int32
    public var availability: VeilgramMediaAvailability

    public init(
        key: VeilgramMediaKey,
        relativePath: String?,
        byteCount: Int64,
        archivedAt: Int32,
        lastAccessedAt: Int32,
        availability: VeilgramMediaAvailability
    ) {
        self.key = key
        self.relativePath = relativePath
        self.byteCount = byteCount
        self.archivedAt = archivedAt
        self.lastAccessedAt = lastAccessedAt
        self.availability = availability
    }
}

public struct VeilgramMediaArchiveDocument: Codable, Equatable {
    public static let currentVersion = 1
    public var version: Int
    public var items: [VeilgramMediaItem]

    public init(version: Int = currentVersion, items: [VeilgramMediaItem] = []) {
        self.version = version
        self.items = items
    }
}

public struct VeilgramMediaEligibility: Equatable {
    public var archiveEligibility: VeilgramArchiveEligibility
    public var bytesAreLocallyAvailable: Bool

    public init(archiveEligibility: VeilgramArchiveEligibility, bytesAreLocallyAvailable: Bool) {
        self.archiveEligibility = archiveEligibility
        self.bytesAreLocallyAvailable = bytesAreLocallyAvailable
    }
}

public enum VeilgramMediaArchiveError: Error, Equatable {
    case unsupportedVersion
    case invalidPath
    case invalidSize
    case tooManyItems
    case documentTooLarge
}

public enum VeilgramMediaArchiveEngine {
    public static let maximumItems = 20_000
    public static let maximumDocumentBytes = 16 * 1024 * 1024

    public static func isEligible(_ value: VeilgramMediaEligibility) -> Bool {
        return value.archiveEligibility.isEligibleForLocalRetention && value.bytesAreLocallyAvailable
    }

    public static func validate(_ item: VeilgramMediaItem) throws {
        guard item.byteCount >= 0 else { throw VeilgramMediaArchiveError.invalidSize }
        switch item.availability {
        case .available:
            guard let path = item.relativePath,
                  !path.isEmpty, !path.hasPrefix("/"), !path.contains(".."), path.count <= 512 else {
                throw VeilgramMediaArchiveError.invalidPath
            }
        case .unavailable:
            guard item.relativePath == nil, item.byteCount == 0 else {
                throw VeilgramMediaArchiveError.invalidPath
            }
        }
    }

    @discardableResult
    public static func appendAvailable(
        document: inout VeilgramMediaArchiveDocument,
        item: VeilgramMediaItem,
        eligibility: VeilgramMediaEligibility
    ) throws -> Bool {
        guard isEligible(eligibility), item.availability == .available else { return false }
        try validate(item)
        if let index = document.items.firstIndex(where: { $0.key == item.key }) {
            guard document.items[index] != item else { return false }
            document.items[index] = item
            return true
        }
        guard document.items.count < maximumItems else { throw VeilgramMediaArchiveError.tooManyItems }
        document.items.append(item)
        return true
    }

    public static func totalAvailableBytes(_ document: VeilgramMediaArchiveDocument) -> Int64 {
        return document.items.reduce(into: 0) { total, item in
            if item.availability == .available { total += item.byteCount }
        }
    }

    public static func enforceQuota(
        document: inout VeilgramMediaArchiveDocument,
        maximumBytes: Int64
    ) -> [VeilgramMediaItem] {
        guard maximumBytes >= 0 else { return [] }
        var total = totalAvailableBytes(document)
        guard total > maximumBytes else { return [] }
        let order = document.items.enumerated()
            .filter { $0.element.availability == .available }
            .sorted {
                if $0.element.lastAccessedAt != $1.element.lastAccessedAt {
                    return $0.element.lastAccessedAt < $1.element.lastAccessedAt
                }
                return $0.element.archivedAt < $1.element.archivedAt
            }
        var evicted = [VeilgramMediaItem]()
        var keys = Set<VeilgramMediaKey>()
        for entry in order where total > maximumBytes {
            total -= entry.element.byteCount
            keys.insert(entry.element.key)
            evicted.append(entry.element)
        }
        document.items.removeAll(where: { keys.contains($0.key) })
        return evicted
    }

    public static func encode(_ document: VeilgramMediaArchiveDocument) throws -> Data {
        guard document.version == VeilgramMediaArchiveDocument.currentVersion else {
            throw VeilgramMediaArchiveError.unsupportedVersion
        }
        guard document.items.count <= maximumItems else {
            throw VeilgramMediaArchiveError.tooManyItems
        }
        for item in document.items { try validate(item) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramMediaArchiveError.documentTooLarge
        }
        return data
    }

    public static func decode(_ data: Data) throws -> VeilgramMediaArchiveDocument {
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramMediaArchiveError.documentTooLarge
        }
        let document = try JSONDecoder().decode(VeilgramMediaArchiveDocument.self, from: data)
        _ = try encode(document)
        return document
    }
}