import Foundation

@main
enum VeilgramLocalCoreIntegrationTests {
    static func main() throws {
        var checks = 0

        let ordinary = VeilgramArchiveEligibility(
            isCloudMessage: true,
            isSecretChat: false,
            isViewOnce: false,
            hasSelfDestructTimeout: false
        )
        precondition(ordinary.isEligibleForLocalRetention)
        checks += 1

        let ephemeral = VeilgramArchiveEligibility(
            isCloudMessage: true,
            isSecretChat: false,
            isViewOnce: true,
            hasSelfDestructTimeout: true
        )
        precondition(!ephemeral.isEligibleForLocalRetention)
        checks += 1

        let key = VeilgramMessageKey(peerId: 42, namespace: 0, id: 7)
        let entity = VeilgramTextEntity(offset: 0, length: 4, kind: "bold")
        let message = VeilgramArchivedMessage(
            key: key,
            messageTimestamp: 10,
            archivedAt: 20,
            text: "test",
            entities: [entity],
            hadMedia: false
        )
        var messages = VeilgramMessageArchiveDocument()
        precondition(try VeilgramMessageArchiveEngine.append(
            document: &messages,
            message: message,
            eligibility: ordinary
        ))
        precondition(try !VeilgramMessageArchiveEngine.append(
            document: &messages,
            message: message,
            eligibility: ordinary
        ))
        let encodedMessages = try VeilgramMessageArchiveEngine.encode(messages)
        precondition(try VeilgramMessageArchiveEngine.decode(encodedMessages) == messages)
        checks += 3

        var edits = VeilgramEditHistoryDocument()
        let revision = VeilgramEditRevision(timestamp: 21, text: "test", entities: [entity])
        precondition(try VeilgramEditHistoryEngine.append(
            document: &edits,
            key: key,
            revision: revision,
            eligibility: ordinary
        ))
        precondition(try !VeilgramEditHistoryEngine.append(
            document: &edits,
            key: key,
            revision: revision,
            eligibility: ordinary
        ))
        precondition(try VeilgramEditHistoryEngine.decode(
            VeilgramEditHistoryEngine.encode(edits)
        ) == edits)
        checks += 3

        let mediaKey = VeilgramMediaKey(
            peerId: 42,
            messageNamespace: 0,
            messageId: 7,
            mediaIndex: 0
        )
        let media = VeilgramMediaItem(
            key: mediaKey,
            relativePath: "media/item.bin",
            byteCount: 100,
            archivedAt: 20,
            lastAccessedAt: 20,
            availability: .available
        )
        var mediaDocument = VeilgramMediaArchiveDocument()
        let mediaEligibility = VeilgramMediaEligibility(
            archiveEligibility: ordinary,
            bytesAreLocallyAvailable: true
        )
        precondition(try VeilgramMediaArchiveEngine.appendAvailable(
            document: &mediaDocument,
            item: media,
            eligibility: mediaEligibility
        ))
        precondition(VeilgramMediaArchiveEngine.totalAvailableBytes(mediaDocument) == 100)
        let evicted = VeilgramMediaArchiveEngine.enforceQuota(
            document: &mediaDocument,
            maximumBytes: 0
        )
        precondition(evicted == [media] && mediaDocument.items.isEmpty)
        checks += 3

        let suite = "veilgram-local-core-\(UUID().uuidString)"
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let store = VeilgramProtectedLocalStore(rootURL: base)
        let archiveStore = VeilgramArchiveStoreAPI(store: store)
        try archiveStore.saveMessages(messages)
        try archiveStore.saveEdits(edits)
        precondition(try archiveStore.loadMessages() == messages)
        precondition(try archiveStore.loadEdits() == edits)
        try archiveStore.removeAll()
        precondition(try archiveStore.loadMessages().messages.isEmpty)
        checks += 5

        print("PASS: \(checks) shared local archive/edit/media integration checks")
    }
}
