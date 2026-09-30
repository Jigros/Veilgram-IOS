import Foundation

@main
enum VeilgramArchivePersistenceTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("veilgram-archive-persistence-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let persistence = VeilgramArchivePersistence(
            store: VeilgramProtectedLocalStore(rootURL: root)
        )

        expect(try persistence.loadMessageArchive().messages.isEmpty, "missing message archive should be empty")
        expect(try persistence.loadEditHistory().records.isEmpty, "missing edit history should be empty")
        expect(try persistence.loadMediaArchive().items.isEmpty, "missing media archive should be empty")

        let message = VeilgramArchivedMessage(
            key: VeilgramArchivedMessageKey(peerId: 1, namespace: 0, id: 2),
            messageTimestamp: 10,
            archivedAt: 20,
            text: "archived",
            entities: [],
            hadMedia: true
        )
        let messageDoc = VeilgramMessageArchiveDocument(messages: [message])
        try persistence.saveMessageArchive(messageDoc)
        expect(try persistence.loadMessageArchive() == messageDoc, "message archive restart roundtrip failed")

        let edit = VeilgramEditHistoryRevision(timestamp: 30, text: "old text", entities: [])
        let editDoc = VeilgramEditHistoryDocument(records: [
            VeilgramEditHistoryRecord(
                message: VeilgramEditHistoryMessageKey(peerId: 1, namespace: 0, id: 2),
                revisions: [edit]
            )
        ])
        try persistence.saveEditHistory(editDoc)
        expect(try persistence.loadEditHistory() == editDoc, "edit history restart roundtrip failed")

        let media = VeilgramMediaArchiveItem(
            key: VeilgramMediaArchiveKey(peerId: 1, messageNamespace: 0, messageId: 2, mediaIndex: 0),
            relativePath: "media/item.bin",
            byteCount: 123,
            archivedAt: 40,
            lastAccessedAt: 50,
            availability: .available
        )
        let mediaDoc = VeilgramMediaArchiveDocument(items: [media])
        try persistence.saveMediaArchive(mediaDoc)
        expect(try persistence.loadMediaArchive() == mediaDoc, "media metadata restart roundtrip failed")

        let names = [
            VeilgramArchivePersistence.messageArchiveFileName,
            VeilgramArchivePersistence.editHistoryFileName,
            VeilgramArchivePersistence.mediaArchiveFileName
        ]
        for name in names {
            let attrs = try FileManager.default.attributesOfItem(atPath: root.appendingPathComponent(name).path)
            let mode = (attrs[.posixPermissions] as? NSNumber)?.intValue
            expect(mode == 0o600, "persisted archive file is not 0600")
        }

        try persistence.removeAllLocalArchiveData()
        for name in names {
            let exists = try persistence.store.fileExists(fileName: name)
            expect(!exists, "remove-all left persisted archive data")
        }

        print("PASS: \(checks) archive persistence integration checks")
    }
}
