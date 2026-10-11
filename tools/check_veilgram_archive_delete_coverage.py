#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "postbox": ROOT / "submodules/Postbox/Sources/Postbox.swift",
    "history_table": ROOT / "submodules/Postbox/Sources/MessageHistoryTable.swift",
    "state": ROOT / "submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift",
    "cached_peer": ROOT / "submodules/TelegramCore/Sources/TelegramEngine/Peers/UpdateCachedPeerData.swift",
    "validation": ROOT / "submodules/TelegramCore/Sources/State/HistoryViewStateValidation.swift",
}

text = {name: path.read_text(encoding="utf-8") for name, path in FILES.items()}

checks = []

def require(name: str, condition: bool, detail: str) -> None:
    checks.append((name, condition, detail))

require(
    "transaction-range-callback",
    "forEachMessage: ((Message) -> Void)? = nil" in text["postbox"]
    and "forEachMessage: forEachMessage" in text["postbox"],
    "Transaction.deleteMessagesInRange must expose and forward an optional removed-message callback.",
)

require(
    "history-table-callback-before-removal",
    "forEachMessage?(message)" in text["history_table"]
    and text["history_table"].find("forEachMessage?(message)")
    < text["history_table"].find("self.processIndexOperations", text["history_table"].find("func removeMessagesInRange")),
    "MessageHistoryTable must expose removed messages while their data is still readable, before processIndexOperations.",
)

global_delete_anchor = "case let .DeleteMessagesWithGlobalIds(ids):"
direct_delete_anchor = "case let .DeleteMessages(ids):"
global_delete_start = text["state"].find(global_delete_anchor)
direct_delete_start = text["state"].find(direct_delete_anchor, global_delete_start)
min_available_start = text["state"].find("case let .UpdateMinAvailableMessage(id):", direct_delete_start)
global_delete_slice = text["state"][global_delete_start:direct_delete_start]
direct_delete_slice = text["state"][direct_delete_start:min_available_start]

require(
    "global-delete-media-copy-before-unlink",
    global_delete_anchor in text["state"]
    and "VeilgramArchiveStateAdapter.enqueueDeletedMedia" in global_delete_slice
    and "completion:" in global_delete_slice
    and "mediaBox.removeCachedResources" in global_delete_slice,
    "Global-id deletion must archive already-local media before cache resources are unlinked.",
)

require(
    "direct-delete-media-adapter",
    direct_delete_anchor in text["state"]
    and "VeilgramArchiveStateAdapter.enqueueDeletedMessage" in direct_delete_slice
    and "mediaBox: mediaBox" in direct_delete_slice,
    "Ordinary DeleteMessages must pass MediaBox into the archive adapter.",
)

state_anchor = "case let .UpdateMinAvailableMessage(id):"
state_slice = text["state"][text["state"].find(state_anchor):]
require(
    "state-min-available-archive",
    state_anchor in text["state"]
    and "forEachMessage: { message in" in state_slice
    and "VeilgramArchiveStateAdapter.enqueueDeletedMessage" in state_slice,
    "Accepted UpdateMinAvailableMessage range deletion must snapshot eligible messages.",
)

cached_anchor = "if let minAvailableMessageId = minAvailableMessageId, minAvailableMessageIdUpdated"
cached_slice = text["cached_peer"][text["cached_peer"].find(cached_anchor):]
require(
    "cached-peer-min-available-archive",
    cached_anchor in text["cached_peer"]
    and "forEachMessage: { message in" in cached_slice
    and "VeilgramArchiveStateAdapter.enqueueDeletedMessage" in cached_slice,
    "Cached peer-data minAvailable range deletion must snapshot eligible messages.",
)

require(
    "history-validation-archive",
    text["validation"].count("VeilgramArchiveStateAdapter.enqueueDeletedMessage") >= 2
    and 'Logger.shared.log("HistoryValidation", "deleting message' in text["validation"]
    and 'Logger.shared.log("HistoryValidation", "deleting thread message' in text["validation"],
    "Both server history-validation deletion paths must snapshot before local removal.",
)

failed = [entry for entry in checks if not entry[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} archive delete-coverage source checks")
