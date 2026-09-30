import Foundation

@main
enum VeilgramMessageFilterPersistenceTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("veilgram-filter-persistence-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let persistence = VeilgramMessageFilterPersistence(
            store: VeilgramProtectedLocalStore(rootURL: root)
        )

        let empty = try persistence.load()
        expect(empty.rules.isEmpty, "missing filter file should load empty")

        let rule = VeilgramMessageFilterRule(
            id: "promo",
            name: "Promo",
            enabled: true,
            action: .label,
            matchers: [VeilgramMessageFilterMatcher(kind: .textContains, value: "promo", caseSensitive: false)],
            peerIds: [100],
            excludedPeerIds: [101],
            reverse: false
        )
        let document = VeilgramMessageFilterDocument(rules: [rule])

        try persistence.save(document)
        let loaded = try persistence.load()
        expect(loaded == document, "protected filter restart roundtrip failed")

        let exported = try persistence.exportEnvelope(document: document, createdAt: 123)
        let imported = try persistence.importEnvelope(exported)
        expect(imported == document, "export/import roundtrip failed")

        let importedAndSaved = try persistence.importAndSave(exported)
        expect(importedAndSaved == document, "importAndSave return mismatch")
        let reloaded = try persistence.load()
        expect(reloaded == document, "importAndSave persistence mismatch")

        let fileURL = root.appendingPathComponent(VeilgramMessageFilterPersistence.fileName)
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let mode = (attrs[.posixPermissions] as? NSNumber)?.intValue
        expect(mode == 0o600, "filter file is not 0600")

        let wrongPayload = try VeilgramTransferEngine.makeEnvelope(
            kind: .editHistory,
            createdAt: 1,
            payload: Data("{}".utf8)
        )
        let wrongData = try VeilgramTransferEngine.encode(wrongPayload)
        do {
            _ = try persistence.importEnvelope(wrongData)
            preconditionFailure("wrong transfer kind accepted")
        } catch VeilgramTransferError.invalidDocument {
            checks += 1
        }

        let credentialPayload = Data(#"{"api_hash":"must-not-export"}"#.utf8)
        do {
            _ = try VeilgramTransferEngine.makeEnvelope(
                kind: .filters,
                createdAt: 1,
                payload: credentialPayload
            )
            preconditionFailure("credential marker accepted")
        } catch VeilgramTransferError.forbiddenCredentialMaterial {
            checks += 1
        }

        try persistence.removeAll()
        let exists = try persistence.store.fileExists(fileName: VeilgramMessageFilterPersistence.fileName)
        expect(!exists, "removeAll left local filter data")

        print("PASS: \(checks) filter persistence integration checks")
    }
}
