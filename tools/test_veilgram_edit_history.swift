import Foundation

@main
enum VeilgramEditHistoryTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let key = VeilgramEditHistoryMessageKey(peerId: 100, namespace: 0, id: 10)
        let eligible = VeilgramEditHistoryEligibility(
            isCloudMessage: true,
            isSecretChat: false,
            isViewOnce: false,
            hasSelfDestructTimeout: false
        )
        var document = VeilgramEditHistoryDocument()
        let first = VeilgramEditHistoryRevision(
            timestamp: 1,
            text: "hello",
            entities: [VeilgramEditHistoryEntity(offset: 0, length: 5, kind: "bold")]
        )
        let appendedFirst = try VeilgramEditHistoryEngine.append(document: &document, key: key, revision: first, eligibility: eligible)
        expect(appendedFirst, "first revision not appended")
        expect(document.records.count == 1, "record missing")
        expect(document.records[0].revisions.count == 1, "revision missing")
        let appendedDuplicate = try VeilgramEditHistoryEngine.append(document: &document, key: key, revision: first, eligibility: eligible)
        expect(!appendedDuplicate, "duplicate revision appended")

        let second = VeilgramEditHistoryRevision(timestamp: 2, text: "hello world", entities: [])
        let appendedSecond = try VeilgramEditHistoryEngine.append(document: &document, key: key, revision: second, eligibility: eligible)
        expect(appendedSecond, "second revision missing")
        expect(document.records[0].revisions == [first, second], "revision ordering changed")

        let encoded = try VeilgramEditHistoryEngine.encode(document)
        let decoded = try VeilgramEditHistoryEngine.decode(encoded)
        expect(decoded == document, "roundtrip mismatch")

        let secret = VeilgramEditHistoryEligibility(isCloudMessage: true, isSecretChat: true, isViewOnce: false, hasSelfDestructTimeout: false)
        let viewOnce = VeilgramEditHistoryEligibility(isCloudMessage: true, isSecretChat: false, isViewOnce: true, hasSelfDestructTimeout: false)
        let selfDestruct = VeilgramEditHistoryEligibility(isCloudMessage: true, isSecretChat: false, isViewOnce: false, hasSelfDestructTimeout: true)
        let nonCloud = VeilgramEditHistoryEligibility(isCloudMessage: false, isSecretChat: false, isViewOnce: false, hasSelfDestructTimeout: false)

        expect(!VeilgramEditHistoryEngine.isEligible(secret), "secret chat accepted")
        expect(!VeilgramEditHistoryEngine.isEligible(viewOnce), "view-once accepted")
        expect(!VeilgramEditHistoryEngine.isEligible(selfDestruct), "self-destruct accepted")
        expect(!VeilgramEditHistoryEngine.isEligible(nonCloud), "non-cloud accepted")

        var blocked = VeilgramEditHistoryDocument()
        let appendedBlocked = try VeilgramEditHistoryEngine.append(document: &blocked, key: key, revision: first, eligibility: secret)
        expect(!appendedBlocked, "blocked revision appended")
        expect(blocked.records.isEmpty, "blocked revision mutated document")

        do {
            let bad = VeilgramEditHistoryRevision(
                timestamp: 1,
                text: "abc",
                entities: [VeilgramEditHistoryEntity(offset: 2, length: 5, kind: "bold")]
            )
            try VeilgramEditHistoryEngine.validate(bad)
            preconditionFailure("invalid entity accepted")
        } catch VeilgramEditHistoryError.invalidEntity {
            checks += 1
        }

        do {
            let long = VeilgramEditHistoryRevision(
                timestamp: 1,
                text: String(repeating: "x", count: VeilgramEditHistoryEngine.maximumTextCharacters + 1),
                entities: []
            )
            try VeilgramEditHistoryEngine.validate(long)
            preconditionFailure("oversized text accepted")
        } catch VeilgramEditHistoryError.textTooLong {
            checks += 1
        }

        var rolling = VeilgramEditHistoryDocument()
        for i in 0..<(VeilgramEditHistoryEngine.maximumRevisionsPerMessage + 5) {
            let revision = VeilgramEditHistoryRevision(timestamp: Int32(i), text: "r\(i)", entities: [])
            _ = try VeilgramEditHistoryEngine.append(document: &rolling, key: key, revision: revision, eligibility: eligible)
        }
        expect(rolling.records[0].revisions.count == VeilgramEditHistoryEngine.maximumRevisionsPerMessage, "revision bound not enforced")
        expect(rolling.records[0].revisions.first?.text == "r5", "oldest revisions were not evicted")

        print("PASS: \(checks) edit-history core checks")
    }
}
