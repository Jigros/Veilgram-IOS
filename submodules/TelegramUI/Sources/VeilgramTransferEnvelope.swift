import Foundation

enum VeilgramTransferKind: String, Codable, Equatable {
    case filters
    case messageArchive
    case editHistory
    case mediaArchiveMetadata
}

struct VeilgramTransferEnvelope: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = currentVersion
    var kind: VeilgramTransferKind
    var createdAt: Int32
    var checksum: UInt32
    var payload: Data
}

enum VeilgramTransferError: Error, Equatable {
    case unsupportedVersion
    case payloadTooLarge
    case checksumMismatch
    case forbiddenCredentialMaterial
    case invalidDocument
}

/// Local transport envelope for Veilgram-owned data only.
/// The checksum is for corruption detection, not authentication/security.
enum VeilgramTransferEngine {
    static let maximumPayloadBytes = 32 * 1024 * 1024
    static let maximumEnvelopeBytes = 48 * 1024 * 1024

    private static let forbiddenMarkers = [
        ""api_hash"",
        ""api_id"",
        ""auth_key"",
        ""authorization"",
        ""stel_token"",
        ""session_token""
    ]

    static func makeEnvelope(
        kind: VeilgramTransferKind,
        createdAt: Int32,
        payload: Data
    ) throws -> VeilgramTransferEnvelope {
        guard payload.count <= maximumPayloadBytes else {
            throw VeilgramTransferError.payloadTooLarge
        }
        guard !containsForbiddenCredentialMaterial(payload) else {
            throw VeilgramTransferError.forbiddenCredentialMaterial
        }
        return VeilgramTransferEnvelope(
            kind: kind,
            createdAt: createdAt,
            checksum: checksum32(payload),
            payload: payload
        )
    }

    static func encode(_ envelope: VeilgramTransferEnvelope) throws -> Data {
        try validate(envelope)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        guard data.count <= maximumEnvelopeBytes else {
            throw VeilgramTransferError.payloadTooLarge
        }
        return data
    }

    static func decode(_ data: Data) throws -> VeilgramTransferEnvelope {
        guard data.count <= maximumEnvelopeBytes else {
            throw VeilgramTransferError.payloadTooLarge
        }
        let envelope: VeilgramTransferEnvelope
        do {
            envelope = try JSONDecoder().decode(VeilgramTransferEnvelope.self, from: data)
        } catch {
            throw VeilgramTransferError.invalidDocument
        }
        try validate(envelope)
        return envelope
    }

    static func validate(_ envelope: VeilgramTransferEnvelope) throws {
        guard envelope.version == VeilgramTransferEnvelope.currentVersion else {
            throw VeilgramTransferError.unsupportedVersion
        }
        guard envelope.payload.count <= maximumPayloadBytes else {
            throw VeilgramTransferError.payloadTooLarge
        }
        guard checksum32(envelope.payload) == envelope.checksum else {
            throw VeilgramTransferError.checksumMismatch
        }
        guard !containsForbiddenCredentialMaterial(envelope.payload) else {
            throw VeilgramTransferError.forbiddenCredentialMaterial
        }
    }

    static func checksum32(_ data: Data) -> UInt32 {
        var value: UInt32 = 2_166_136_261
        for byte in data {
            value ^= UInt32(byte)
            value = value &* 16_777_619
        }
        return value
    }

    static func containsForbiddenCredentialMaterial(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8)?.lowercased() else {
            return false
        }
        return forbiddenMarkers.contains(where: { text.contains($0) })
    }
}
