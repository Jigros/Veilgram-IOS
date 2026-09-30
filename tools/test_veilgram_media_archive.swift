import Foundation

@main
enum VeilgramMediaArchiveTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let key1 = VeilgramMediaArchiveKey(peerId: 1, messageNamespace: 0, messageId: 1, mediaIndex: 0)
        let key2 = VeilgramMediaArchiveKey(peerId: 1, messageNamespace: 0, messageId: 2, mediaIndex: 0)
        let eligible = VeilgramMediaArchiveEligibility(
            isCloudMessage: true,
            isSecretChat: false,
            isViewOnce: false,
            hasSelfDestructTimeout: false,
            bytesAreLocallyAvailable: true
        )
        let item1 = VeilgramMediaArchiveItem(
            key: key1,
            relativePath: "media/a.bin",
            byteCount: 80,
            archivedAt: 10,
            lastAccessedAt: 20,
            availability: .available
        )
        let item2 = VeilgramMediaArchiveItem(
            key: key2,
            relativePath: "media/b.bin",
            byteCount: 70,
            archivedAt: 30,
            lastAccessedAt: 40,
            availability: .available
        )

        var document = VeilgramMediaArchiveDocument()
        expect(try VeilgramMediaArchiveEngine.appendAvailable(document: &document, item: item1, eligibility: eligible), "item1 not archived")
        expect(try VeilgramMediaArchiveEngine.appendAvailable(document: &document, item: item2, eligibility: eligible), "item2 not archived")
        expect(VeilgramMediaArchiveEngine.totalAvailableBytes(document) == 150, "byte total mismatch")

        let evicted = VeilgramMediaArchiveEngine.enforceQuota(document: &document, maximumBytes: 100)
        expect(evicted.map(\.key) == [key1], "LRU eviction mismatch")
        expect(document.items.map(\.key) == [key2], "remaining item mismatch")

        let data = try VeilgramMediaArchiveEngine.encode(document)
        let decoded = try VeilgramMediaArchiveEngine.decode(data)
        expect(decoded == document, "roundtrip mismatch")

        var unavailable = VeilgramMediaArchiveDocument()
        VeilgramMediaArchiveEngine.markUnavailable(document: &unavailable, key: key1, at: 55)
        expect(unavailable.items.count == 1, "unavailable placeholder missing")
        expect(unavailable.items[0].availability == .unavailable, "placeholder state mismatch")
        expect(unavailable.items[0].relativePath == nil && unavailable.items[0].byteCount == 0, "placeholder leaked path/size")

        let blockedCases = [
            VeilgramMediaArchiveEligibility(isCloudMessage: false, isSecretChat: false, isViewOnce: false, hasSelfDestructTimeout: false, bytesAreLocallyAvailable: true),
            VeilgramMediaArchiveEligibility(isCloudMessage: true, isSecretChat: true, isViewOnce: false, hasSelfDestructTimeout: false, bytesAreLocallyAvailable: true),
            VeilgramMediaArchiveEligibility(isCloudMessage: true, isSecretChat: false, isViewOnce: true, hasSelfDestructTimeout: false, bytesAreLocallyAvailable: true),
            VeilgramMediaArchiveEligibility(isCloudMessage: true, isSecretChat: false, isViewOnce: false, hasSelfDestructTimeout: true, bytesAreLocallyAvailable: true),
            VeilgramMediaArchiveEligibility(isCloudMessage: true, isSecretChat: false, isViewOnce: false, hasSelfDestructTimeout: false, bytesAreLocallyAvailable: false)
        ]
        for blocked in blockedCases {
            var tmp = VeilgramMediaArchiveDocument()
            let accepted = try VeilgramMediaArchiveEngine.appendAvailable(document: &tmp, item: item1, eligibility: blocked)
            expect(!accepted && tmp.items.isEmpty, "ineligible media archived")
        }

        do {
            let bad = VeilgramMediaArchiveItem(
                key: key1,
                relativePath: "../outside",
                byteCount: 1,
                archivedAt: 1,
                lastAccessedAt: 1,
                availability: .available
            )
            try VeilgramMediaArchiveEngine.validate(bad)
            preconditionFailure("unsafe relative path accepted")
        } catch VeilgramMediaArchiveError.invalidPath {
            checks += 1
        }

        var zeroQuota = VeilgramMediaArchiveDocument(items: [item1, item2])
        let all = VeilgramMediaArchiveEngine.enforceQuota(document: &zeroQuota, maximumBytes: 0)
        expect(all.count == 2 && zeroQuota.items.isEmpty, "zero quota did not evict all available media")

        print("PASS: \(checks) media-archive core checks")
    }
}
