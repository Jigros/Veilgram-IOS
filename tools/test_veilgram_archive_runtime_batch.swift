import Foundation

@main
enum VeilgramArchiveRuntimeBatchTests {
    static func main() throws {
        var checks = 0

        precondition(VeilgramArchiveRuntimeBatchPolicy.flushDelayMilliseconds == 150)
        precondition(VeilgramArchiveRuntimeBatchPolicy.maximumPendingEventsPerAccount == 128)
        precondition(VeilgramArchiveRuntimeBatchPolicy.retryDelayMilliseconds(attempt: 1) == 250)
        precondition(VeilgramArchiveRuntimeBatchPolicy.retryDelayMilliseconds(attempt: 2) == 500)
        precondition(VeilgramArchiveRuntimeBatchPolicy.retryDelayMilliseconds(attempt: 3) == 1_000)
        precondition(VeilgramArchiveRuntimeBatchPolicy.retryDelayMilliseconds(attempt: 4) == 2_000)
        precondition(VeilgramArchiveRuntimeBatchPolicy.retryDelayMilliseconds(attempt: 5) == 4_000)
        precondition(VeilgramArchiveRuntimeBatchPolicy.retryDelayMilliseconds(attempt: 6) == 5_000)
        precondition(VeilgramArchiveRuntimeBatchPolicy.retryDelayMilliseconds(attempt: 50) == 5_000)
        checks += 9

        let ordinary = VeilgramArchiveEligibility(
            isCloudMessage: true,
            isSecretChat: false,
            isViewOnce: false,
            hasSelfDestructTimeout: false
        )

        func message(id: Int32, archivedAt: Int32? = nil) -> VeilgramArchivedMessage {
            return VeilgramArchivedMessage(
                key: VeilgramMessageKey(peerId: 100, namespace: 0, id: id),
                messageTimestamp: id,
                archivedAt: archivedAt ?? id,
                text: "message-\(id)",
                entities: [],
                hadMedia: false
            )
        }

        // 1000 unique deletes should naturally split into seven full 128-event
        // batches plus a 104-event remainder.
        var deleteBatch = VeilgramArchivePendingBatch()
        var deleteFlushes = 0
        for id in 0 ..< 1_000 {
            deleteBatch.appendDeletedMessage(message(id: Int32(id)), eligibility: ordinary)
            if deleteBatch.eventCount >= VeilgramArchiveRuntimeBatchPolicy.maximumPendingEventsPerAccount {
                precondition(deleteBatch.eventCount == 128)
                deleteFlushes += 1
                deleteBatch = VeilgramArchivePendingBatch()
            }
        }
        precondition(deleteFlushes == 7)
        precondition(deleteBatch.eventCount == 104)
        checks += 2

        // Repeated snapshots for one key coalesce to one pending write and retain
        // only the newest snapshot without duplicating order entries.
        var coalescedDeletes = VeilgramArchivePendingBatch()
        for version in 0 ..< 1_000 {
            let updated = VeilgramArchivedMessage(
                key: VeilgramMessageKey(peerId: 100, namespace: 0, id: 7),
                messageTimestamp: 7,
                archivedAt: Int32(version),
                text: "version-\(version)",
                entities: [],
                hadMedia: false
            )
            coalescedDeletes.appendDeletedMessage(updated, eligibility: ordinary)
        }
        precondition(coalescedDeletes.eventCount == 1)
        precondition(coalescedDeletes.deletedMessageOrder.count == 1)
        precondition(
            coalescedDeletes.deletedMessages[
                VeilgramMessageKey(peerId: 100, namespace: 0, id: 7)
            ]?.message.text == "version-999"
        )
        checks += 3

        // Consecutive duplicate revisions for one message are dropped.
        var duplicateEdits = VeilgramArchivePendingBatch()
        let editKey = VeilgramMessageKey(peerId: 100, namespace: 0, id: 8)
        let duplicateRevision = VeilgramEditRevision(
            timestamp: 1,
            text: "same",
            entities: []
        )
        for _ in 0 ..< 1_000 {
            duplicateEdits.appendEditRevision(
                key: editKey,
                revision: duplicateRevision,
                eligibility: ordinary
            )
        }
        precondition(duplicateEdits.eventCount == 1)
        precondition(duplicateEdits.editRevisions.count == 1)
        checks += 2

        // 1000 distinct edit revisions preserve order across threshold-sized
        // batches instead of coalescing different revisions.
        var editBatch = VeilgramArchivePendingBatch()
        var editFlushes = 0
        var lastSeenTimestamp: Int32 = -1
        for version in 0 ..< 1_000 {
            let revision = VeilgramEditRevision(
                timestamp: Int32(version),
                text: "revision-\(version)",
                entities: []
            )
            editBatch.appendEditRevision(
                key: editKey,
                revision: revision,
                eligibility: ordinary
            )
            precondition(editBatch.editRevisions.last?.revision.timestamp == Int32(version))
            lastSeenTimestamp = Int32(version)
            if editBatch.eventCount >= VeilgramArchiveRuntimeBatchPolicy.maximumPendingEventsPerAccount {
                precondition(editBatch.eventCount == 128)
                editFlushes += 1
                editBatch = VeilgramArchivePendingBatch()
            }
        }
        precondition(lastSeenTimestamp == 999)
        precondition(editFlushes == 7)
        precondition(editBatch.eventCount == 104)
        checks += 3

        // Account-scoped batches remain independent.
        var byAccount: [Int64: VeilgramArchivePendingBatch] = [:]
        var first = VeilgramArchivePendingBatch()
        first.appendDeletedMessage(message(id: 1), eligibility: ordinary)
        var second = VeilgramArchivePendingBatch()
        second.appendDeletedMessage(
            VeilgramArchivedMessage(
                key: VeilgramMessageKey(peerId: 200, namespace: 0, id: 1),
                messageTimestamp: 1,
                archivedAt: 1,
                text: "second-account",
                entities: [],
                hadMedia: false
            ),
            eligibility: ordinary
        )
        byAccount[100] = first
        byAccount[200] = second
        precondition(byAccount[100]?.eventCount == 1)
        precondition(byAccount[200]?.eventCount == 1)
        precondition(byAccount[100]?.deletedMessageOrder.first?.peerId == 100)
        precondition(byAccount[200]?.deletedMessageOrder.first?.peerId == 200)
        checks += 4

        // A failed older batch merged with newer work must keep older edit order,
        // while deleted-message snapshots still resolve to the newest value.
        var older = VeilgramArchivePendingBatch()
        older.retryAttempt = 2
        older.appendDeletedMessage(
            VeilgramArchivedMessage(
                key: VeilgramMessageKey(peerId: 100, namespace: 0, id: 9),
                messageTimestamp: 9,
                archivedAt: 10,
                text: "older-delete",
                entities: [],
                hadMedia: false
            ),
            eligibility: ordinary
        )
        older.appendEditRevision(
            key: editKey,
            revision: VeilgramEditRevision(timestamp: 10, text: "older-edit", entities: []),
            eligibility: ordinary
        )

        var newer = VeilgramArchivePendingBatch()
        newer.appendDeletedMessage(
            VeilgramArchivedMessage(
                key: VeilgramMessageKey(peerId: 100, namespace: 0, id: 9),
                messageTimestamp: 9,
                archivedAt: 11,
                text: "newer-delete",
                entities: [],
                hadMedia: false
            ),
            eligibility: ordinary
        )
        newer.appendEditRevision(
            key: editKey,
            revision: VeilgramEditRevision(timestamp: 11, text: "newer-edit", entities: []),
            eligibility: ordinary
        )

        older.mergeNewer(newer)
        precondition(older.retryAttempt == 2)
        precondition(older.deletedMessages[
            VeilgramMessageKey(peerId: 100, namespace: 0, id: 9)
        ]?.message.text == "newer-delete")
        precondition(older.editRevisions.map { $0.revision.text } == ["older-edit", "newer-edit"])
        checks += 3

        var mutationBatch = older
        mutationBatch.discardDeletedMessages()
        precondition(mutationBatch.deletedMessages.isEmpty)
        precondition(mutationBatch.deletedMessageOrder.isEmpty)
        precondition(!mutationBatch.editRevisions.isEmpty)
        mutationBatch.discardEditRevisions()
        precondition(mutationBatch.isEmpty)
        checks += 4

        print("PASS: \(checks) archive runtime batching/retry policy checks")
    }
}
