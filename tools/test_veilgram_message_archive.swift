import Foundation

@main
enum VeilgramMessageArchiveTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let key = VeilgramArchivedMessageKey(peerId: 100, namespace: 0, id: 1)
        let eligible = VeilgramMessageArchiveEligibility(
            isCloudMessage: true,
            isSecretChat: false,
            isViewOnce: false,
            hasSelfDestructTimeout: false
        )
        let message = VeilgramArchivedMessage(
            key: key,
            messageTimestamp: 10,
            archivedAt: 100,
            text: "hello",
            entities: [VeilgramArchivedMessageEntity(offset: 0, length: 5, kind: "bold")],
            hadMedia: false
        )

        var document = VeilgramMessageArchiveDocument()
        let appended = try VeilgramMessageArchiveEngine.append(document: &document, message: message, eligibility: eligible)
        expect(appended, "eligible message not archived")
        expect(document.messages == [message], "archive contents mismatch")

        let duplicate = try VeilgramMessageArchiveEngine.append(document: &document, message: message, eligibility: eligible)
        expect(!duplicate, "duplicate snapshot appended")

        var updated = message
        updated.text = "edited before deletion"
        let replaced = try VeilgramMessageArchiveEngine.append(document: &document, message: updated, eligibility: eligible)
        expect(replaced, "existing snapshot not updated")
        expect(document.messages.count == 1 && document.messages[0].text == updated.text, "snapshot replacement failed")

        let data = try VeilgramMessageArchiveEngine.encode(document)
        let roundtrip = try VeilgramMessageArchiveEngine.decode(data)
        expect(roundtrip == document, "archive JSON roundtrip failed")

        let blockedCases = [
            VeilgramMessageArchiveEligibility(isCloudMessage: false, isSecretChat: false, isViewOnce: false, hasSelfDestructTimeout: false),
            VeilgramMessageArchiveEligibility(isCloudMessage: true, isSecretChat: true, isViewOnce: false, hasSelfDestructTimeout: false),
            VeilgramMessageArchiveEligibility(isCloudMessage: true, isSecretChat: false, isViewOnce: true, hasSelfDestructTimeout: false),
            VeilgramMessageArchiveEligibility(isCloudMessage: true, isSecretChat: false, isViewOnce: false, hasSelfDestructTimeout: true)
        ]
        for blocked in blockedCases {
            var tmp = VeilgramMessageArchiveDocument()
            let accepted = try VeilgramMessageArchiveEngine.append(document: &tmp, message: message, eligibility: blocked)
            expect(!accepted && tmp.messages.isEmpty, "ineligible message was archived")
        }

        var pruneDoc = VeilgramMessageArchiveDocument(messages: [
            VeilgramArchivedMessage(key: key, messageTimestamp: 1, archivedAt: 10, text: "old", entities: [], hadMedia: false),
            VeilgramArchivedMessage(key: VeilgramArchivedMessageKey(peerId: 100, namespace: 0, id: 2), messageTimestamp: 2, archivedAt: 90, text: "new", entities: [], hadMedia: false)
        ])
        VeilgramMessageArchiveEngine.prune(document: &pruneDoc, now: 100, retentionSeconds: 20)
        expect(pruneDoc.messages.count == 1 && pruneDoc.messages[0].text == "new", "retention pruning failed")

        VeilgramMessageArchiveEngine.remove(document: &pruneDoc, key: pruneDoc.messages[0].key)
        expect(pruneDoc.messages.isEmpty, "explicit delete failed")

        var zeroRetention = VeilgramMessageArchiveDocument(messages: [message])
        VeilgramMessageArchiveEngine.prune(document: &zeroRetention, now: 100, retentionSeconds: 0)
        expect(zeroRetention.messages.isEmpty, "zero retention did not clear archive")

        do {
            let invalid = VeilgramArchivedMessage(
                key: key,
                messageTimestamp: 1,
                archivedAt: 1,
                text: "abc",
                entities: [VeilgramArchivedMessageEntity(offset: 2, length: 5, kind: "bold")],
                hadMedia: false
            )
            try VeilgramMessageArchiveEngine.validate(invalid)
            preconditionFailure("invalid entity accepted")
        } catch VeilgramMessageArchiveError.invalidEntity {
            checks += 1
        }

        print("PASS: \(checks) message-archive core checks")
    }
}
