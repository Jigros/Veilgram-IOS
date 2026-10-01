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

    /// Retention eligibility is no longer hard-coded from Telegram message semantics.
    ///
    /// The flags above are descriptive metadata for callers and UI. Build/runtime
    /// policy may still choose not to archive a particular source path, but this
    /// shared model does not silently reject view-once, self-destruct or secret
    /// content on its own.
    public var isEligibleForLocalRetention: Bool {
        return true
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