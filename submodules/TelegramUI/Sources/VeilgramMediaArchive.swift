import Foundation

struct VeilgramMediaArchiveKey: Codable, Hashable, Equatable {
    var peerId: Int64
    var messageNamespace: Int32
    var messageId: Int32
    var mediaIndex: Int
}

enum VeilgramMediaArchiveAvailability: String, Codable, Equatable {
    case available
    case unavailable
}

struct VeilgramMediaArchiveItem: Codable, Equatable {
    var key: VeilgramMediaArchiveKey
    var relativePath: String?
    var byteCount: Int64
    var archivedAt: Int32
    var lastAccessedAt: Int32
    var availability: VeilgramMediaArchiveAvailability
}

struct VeilgramMediaArchiveDocument: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = currentVersion
    var items: [VeilgramMediaArchiveItem] = []
}

struct VeilgramMediaArchiveEligibility {
    var isCloudMessage: Bool
    var isSecretChat: Bool
    var isViewOnce: Bool
    var hasSelfDestructTimeout: Bool
    var bytesAreLocallyAvailable: Bool
}

enum VeilgramMediaArchiveError: Error, Equatable {
    case unsupportedVersion
    case invalidPath
    case invalidSize
    case tooManyItems
    case documentTooLarge
}

/// Local quota/metadata core only. This module never downloads media and never
/// fabricates availability. Integration may archive bytes only when Telegram
/// already has those bytes locally and the eligibility gate passes.
enum VeilgramMediaArchiveEngine {
    static let maximumItems = 20_000
    static let maximumDocumentBytes = 16 * 1024 * 1024

    static func isEligible(_ value: VeilgramMediaArchiveEligibility) -> Bool {
        return value.isCloudMessage
            && !value.isSecretChat
            && !value.isViewOnce
            && !value.hasSelfDestructTimeout
            && value.bytesAreLocallyAvailable
    }

    static func validate(_ item: VeilgramMediaArchiveItem) throws {
        guard item.byteCount >= 0 else {
            throw VeilgramMediaArchiveError.invalidSize
        }

        switch item.availability {
        case .available:
            guard let path = item.relativePath,
                  !path.isEmpty,
                  !path.hasPrefix("/"),
                  !path.contains(".."),
                  path.count <= 512 else {
                throw VeilgramMediaArchiveError.invalidPath
            }
        case .unavailable:
            guard item.relativePath == nil, item.byteCount == 0 else {
                throw VeilgramMediaArchiveError.invalidPath
            }
        }
    }

    @discardableResult
    static func appendAvailable(
        document: inout VeilgramMediaArchiveDocument,
        item: VeilgramMediaArchiveItem,
        eligibility: VeilgramMediaArchiveEligibility
    ) throws -> Bool {
        guard isEligible(eligibility) else {
            return false
        }
        guard item.availability == .available else {
            return false
        }
        try validate(item)

        if let index = document.items.firstIndex(where: { $0.key == item.key }) {
            if document.items[index] == item {
                return false
            }
            document.items[index] = item
            return true
        }

        guard document.items.count < maximumItems else {
            throw VeilgramMediaArchiveError.tooManyItems
        }
        document.items.append(item)
        return true
    }

    static func markUnavailable(
        document: inout VeilgramMediaArchiveDocument,
        key: VeilgramMediaArchiveKey,
        at timestamp: Int32
    ) {
        let placeholder = VeilgramMediaArchiveItem(
            key: key,
            relativePath: nil,
            byteCount: 0,
            archivedAt: timestamp,
            lastAccessedAt: timestamp,
            availability: .unavailable
        )
        if let index = document.items.firstIndex(where: { $0.key == key }) {
            document.items[index] = placeholder
        } else if document.items.count < maximumItems {
            document.items.append(placeholder)
        }
    }

    static func totalAvailableBytes(_ document: VeilgramMediaArchiveDocument) -> Int64 {
        return document.items.reduce(into: Int64(0)) { partial, item in
            if item.availability == .available {
                partial += item.byteCount
            }
        }
    }

    /// Returns evicted metadata entries so integration can delete only its own
    /// archive copies after updating the document.
    static func enforceQuota(
        document: inout VeilgramMediaArchiveDocument,
        maximumBytes: Int64
    ) -> [VeilgramMediaArchiveItem] {
        guard maximumBytes >= 0 else {
            return []
        }
        var total = totalAvailableBytes(document)
        guard total > maximumBytes else {
            return []
        }

        let order = document.items.enumerated()
            .filter { $0.element.availability == .available }
            .sorted {
                if $0.element.lastAccessedAt != $1.element.lastAccessedAt {
                    return $0.element.lastAccessedAt < $1.element.lastAccessedAt
                }
                return $0.element.archivedAt < $1.element.archivedAt
            }

        var evictedKeys = Set<VeilgramMediaArchiveKey>()
        var evicted: [VeilgramMediaArchiveItem] = []
        for entry in order {
            if total <= maximumBytes {
                break
            }
            total -= entry.element.byteCount
            evictedKeys.insert(entry.element.key)
            evicted.append(entry.element)
        }
        document.items.removeAll(where: { evictedKeys.contains($0.key) })
        return evicted
    }

    static func encode(_ document: VeilgramMediaArchiveDocument) throws -> Data {
        guard document.version == VeilgramMediaArchiveDocument.currentVersion else {
            throw VeilgramMediaArchiveError.unsupportedVersion
        }
        guard document.items.count <= maximumItems else {
            throw VeilgramMediaArchiveError.tooManyItems
        }
        for item in document.items {
            try validate(item)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramMediaArchiveError.documentTooLarge
        }
        return data
    }

    static func decode(_ data: Data) throws -> VeilgramMediaArchiveDocument {
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramMediaArchiveError.documentTooLarge
        }
        let document = try JSONDecoder().decode(VeilgramMediaArchiveDocument.self, from: data)
        _ = try encode(document)
        return document
    }
}
