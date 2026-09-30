import Foundation

@main
enum VeilgramTransferEnvelopeTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let payload = Data(#"{"rules":[{"id":"promo"}]}"#.utf8)
        let envelope = try VeilgramTransferEngine.makeEnvelope(
            kind: .filters,
            createdAt: 123,
            payload: payload
        )
        expect(envelope.checksum == VeilgramTransferEngine.checksum32(payload), "checksum mismatch at creation")

        let encoded = try VeilgramTransferEngine.encode(envelope)
        let decoded = try VeilgramTransferEngine.decode(encoded)
        expect(decoded == envelope, "envelope roundtrip mismatch")

        var corrupted = envelope
        corrupted.payload = Data(#"{"rules":[{"id":"other"}]}"#.utf8)
        do {
            try VeilgramTransferEngine.validate(corrupted)
            preconditionFailure("corruption accepted")
        } catch VeilgramTransferError.checksumMismatch {
            checks += 1
        }

        do {
            _ = try VeilgramTransferEngine.makeEnvelope(
                kind: .filters,
                createdAt: 1,
                payload: Data(#"{"api_hash":"secret"}"#.utf8)
            )
            preconditionFailure("api hash exported")
        } catch VeilgramTransferError.forbiddenCredentialMaterial {
            checks += 1
        }

        do {
            _ = try VeilgramTransferEngine.makeEnvelope(
                kind: .messageArchive,
                createdAt: 1,
                payload: Data(#"{"auth_key":"secret"}"#.utf8)
            )
            preconditionFailure("auth key exported")
        } catch VeilgramTransferError.forbiddenCredentialMaterial {
            checks += 1
        }

        var wrongVersion = envelope
        wrongVersion.version = 99
        do {
            try VeilgramTransferEngine.validate(wrongVersion)
            preconditionFailure("unsupported version accepted")
        } catch VeilgramTransferError.unsupportedVersion {
            checks += 1
        }

        let invalid = Data("{not-json}".utf8)
        do {
            _ = try VeilgramTransferEngine.decode(invalid)
            preconditionFailure("invalid JSON accepted")
        } catch VeilgramTransferError.invalidDocument {
            checks += 1
        }

        let binary = Data([0xff, 0x00, 0x01, 0x02])
        let binaryEnvelope = try VeilgramTransferEngine.makeEnvelope(
            kind: .mediaArchiveMetadata,
            createdAt: 2,
            payload: binary
        )
        expect(binaryEnvelope.payload == binary, "binary payload changed")

        expect(
            VeilgramTransferEngine.checksum32(payload) == VeilgramTransferEngine.checksum32(payload),
            "checksum is not deterministic"
        )

        print("PASS: \(checks) import-export envelope checks")
    }
}
