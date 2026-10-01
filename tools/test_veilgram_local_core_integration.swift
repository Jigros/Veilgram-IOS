import Foundation

@main
enum VeilgramLocalCoreIntegrationTests {
    static func main() throws {
        var checks = 0

        let preferenceSuite = "veilgram-runtime-prefs-\(UUID().uuidString)"
        let preferenceDefaults = UserDefaults(suiteName: preferenceSuite)!
        defer { preferenceDefaults.removePersistentDomain(forName: preferenceSuite) }
        let preferenceAccount: Int64 = 99
        precondition(!VeilgramArchiveRuntimePreferences.messageArchiveEnabled(
            accountPeerId: preferenceAccount,
            defaults: preferenceDefaults
        ))
        precondition(!VeilgramArchiveRuntimePreferences.editHistoryEnabled(
            accountPeerId: preferenceAccount,
            defaults: preferenceDefaults
        ))
        VeilgramArchiveRuntimePreferences.setMessageArchiveEnabled(
            true,
            accountPeerId: preferenceAccount,
            defaults: preferenceDefaults
        )
        precondition(VeilgramArchiveRuntimePreferences.messageArchiveEnabled(
            accountPeerId: preferenceAccount,
            defaults: preferenceDefaults
        ))
        precondition(!VeilgramArchiveRuntimePreferences.editHistoryEnabled(
            accountPeerId: preferenceAccount,
            defaults: preferenceDefaults
        ))
        VeilgramArchiveRuntimePreferences.setEditHistoryEnabled(
            true,
            accountPeerId: preferenceAccount,
            defaults: preferenceDefaults
        )
        precondition(VeilgramArchiveRuntimePreferences.editHistoryEnabled(
            accountPeerId: preferenceAccount,
            defaults: preferenceDefaults
        ))
        checks += 5

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
        let didAppendMessage = try VeilgramMessageArchiveEngine.append(
            document: &messages,
            message: message,
            eligibility: ordinary
        )
        precondition(didAppendMessage)
        let didAppendDuplicateMessage = try VeilgramMessageArchiveEngine.append(
            document: &messages,
            message: message,
            eligibility: ordinary
        )
        precondition(!didAppendDuplicateMessage)
        let encodedMessages = try VeilgramMessageArchiveEngine.encode(messages)
        let decodedMessages = try VeilgramMessageArchiveEngine.decode(encodedMessages)
        precondition(decodedMessages == messages)
        checks += 3

        var edits = VeilgramEditHistoryDocument()
        let revision = VeilgramEditRevision(timestamp: 21, text: "test", entities: [entity])
        let didAppendRevision = try VeilgramEditHistoryEngine.append(
            document: &edits,
            key: key,
            revision: revision,
            eligibility: ordinary
        )
        precondition(didAppendRevision)
        let didAppendDuplicateRevision = try VeilgramEditHistoryEngine.append(
            document: &edits,
            key: key,
            revision: revision,
            eligibility: ordinary
        )
        precondition(!didAppendDuplicateRevision)
        let encodedEdits = try VeilgramEditHistoryEngine.encode(edits)
        let decodedEdits = try VeilgramEditHistoryEngine.decode(encodedEdits)
        precondition(decodedEdits == edits)
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
        let didAppendMedia = try VeilgramMediaArchiveEngine.appendAvailable(
            document: &mediaDocument,
            item: media,
            eligibility: mediaEligibility
        )
        precondition(didAppendMedia)
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
        let rootValues = try base.resourceValues(forKeys: [.isExcludedFromBackupKey])
        precondition(rootValues.isExcludedFromBackup == true)
        let messageFile = base.appendingPathComponent("message-archive-v1.json")
        let fileValues = try messageFile.resourceValues(forKeys: [.isExcludedFromBackupKey])
        precondition(fileValues.isExcludedFromBackup == true)
        checks += 2
        let loadedMessages = try archiveStore.loadMessages()
        let loadedEdits = try archiveStore.loadEdits()
        precondition(loadedMessages == messages)
        precondition(loadedEdits == edits)
        let messageExport = try archiveStore.exportMessages(createdAt: 100)
        let editExport = try archiveStore.exportEdits(createdAt: 100)
        let mediaExport = try archiveStore.exportMediaMetadata(createdAt: 100)

        try archiveStore.removeAll()
        let emptiedMessages = try archiveStore.loadMessages()
        precondition(emptiedMessages.messages.isEmpty)

        try archiveStore.importMessages(messageExport)
        try archiveStore.importEdits(editExport)
        try archiveStore.importMediaMetadata(mediaExport)
        let importedMessages = try archiveStore.loadMessages()
        let importedEdits = try archiveStore.loadEdits()
        let importedMedia = try archiveStore.loadMedia()
        precondition(importedMessages == messages)
        precondition(importedEdits == edits)
        precondition(importedMedia == mediaDocument)

        do {
            try archiveStore.importEdits(messageExport)
            preconditionFailure("wrong archive envelope kind was accepted")
        } catch {
        }
        checks += 11

        let lifecycleRoot = base.appendingPathComponent("logout-account", isDirectory: true)
        let lifecycleStore = VeilgramProtectedLocalStore(rootURL: lifecycleRoot)
        try lifecycleStore.write(Data("local".utf8), fileName: "message-filters-v1.json")
        let lifecycleSuite = "veilgram-lifecycle-\(UUID().uuidString)"
        let lifecycleDefaults = UserDefaults(suiteName: lifecycleSuite)!
        defer { lifecycleDefaults.removePersistentDomain(forName: lifecycleSuite) }
        let lifecycleAccountId: Int64 = 424242
        lifecycleDefaults.set(true, forKey: "veilgram.archive.runtime.v1.\(lifecycleAccountId).editHistory")
        lifecycleDefaults.set(Data([1, 2, 3]), forKey: "veilgram.filters.runtime.v1.\(lifecycleAccountId)")
        lifecycleDefaults.set(true, forKey: "veilgram.settings.v1.\(lifecycleAccountId).channelAdFilterEnabled")
        lifecycleDefaults.set(true, forKey: "unrelated.setting")
        try VeilgramLocalDataLifecycle.remove(
            store: lifecycleStore,
            accountPeerId: lifecycleAccountId,
            defaults: lifecycleDefaults
        )
        precondition(!FileManager.default.fileExists(atPath: lifecycleRoot.path))
        precondition(lifecycleDefaults.object(forKey: "veilgram.archive.runtime.v1.\(lifecycleAccountId).editHistory") == nil)
        precondition(lifecycleDefaults.object(forKey: "veilgram.filters.runtime.v1.\(lifecycleAccountId)") == nil)
        precondition(lifecycleDefaults.object(forKey: "veilgram.settings.v1.\(lifecycleAccountId).channelAdFilterEnabled") == nil)
        precondition(lifecycleDefaults.bool(forKey: "unrelated.setting"))
        checks += 5

        print("PASS: \(checks) shared local archive/edit/media integration checks")
    }
}
