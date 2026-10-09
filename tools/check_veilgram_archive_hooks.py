#!/usr/bin/env python3
from pathlib import Path

state = Path("submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift").read_text()
adapter = Path("submodules/TelegramCore/Sources/State/VeilgramArchiveStateAdapter.swift").read_text()

delete_hook_count = state.count("VeilgramArchiveStateAdapter.enqueueDeletedMessage")
edit_hook_count = state.count("VeilgramArchiveStateAdapter.enqueuePreviousEditRevision")
assert delete_hook_count >= 2, f"expected at least two delete hooks, found {delete_hook_count}"
assert edit_hook_count >= 1, f"expected at least one edit hook, found {edit_hook_count}"

global_case = state.index("case let .DeleteMessagesWithGlobalIds(ids):")
global_delete = state.index("transaction.deleteMessagesWithGlobalIds", global_case)
global_hook = state.index("VeilgramArchiveStateAdapter.enqueueDeletedMessage", global_case)
assert global_hook < global_delete, "global-id snapshot must happen before Postbox deletion"

direct_case = state.index("case let .DeleteMessages(ids):")
direct_delete = state.index("_internal_deleteMessages", direct_case)
direct_hook = state.index("VeilgramArchiveStateAdapter.enqueueDeletedMessage", direct_case)
assert direct_hook < direct_delete, "MessageId snapshot must happen before Postbox deletion"

required_adapter_contract = [
    "VeilgramArchiveEligibility",
    "eligibility.isEligibleForLocalRetention",
]
for symbol in required_adapter_contract:
    assert symbol in adapter, f"missing archive eligibility contract: {symbol}"

runtime = Path("submodules/VeilgramLocalFeatures/Sources/VeilgramArchiveRuntimeWriter.swift").read_text()
media = adapter[adapter.index("static func localMediaCandidates("):adapter.index("private static func preferredExtension(")]
assert "message.minAutoremoveOrClearTimeout == nil || message.isCopyProtected()" in media
assert "message.media.contains(where: { $0 is TelegramMediaExpiredContent })" in media
assert "isEphemeralLocalMedia && sourcePath == nil" in media
assert "mediaBox.completedResourcePath(resource)" in media
assert "isEphemeralLocalMedia: isEphemeralLocalMedia" in media
assert "candidate.isEphemeralLocalMedia" in runtime
assert "candidate.eligibility.isEligibleForEphemeralLocalMedia" in runtime
assert "VeilgramArchiveRuntimePreferences.ephemeralLocalMediaEnabled" in runtime
assert "isEphemeralLocalMedia: candidate.isEphemeralLocalMedia" in runtime
expiry = Path("submodules/TelegramCore/Sources/State/ManagedAutoremoveMessageOperations.swift").read_text()
assert expiry.count("VeilgramArchiveStateAdapter.enqueueDeletedMessage(") == 2
assert expiry.index("VeilgramArchiveStateAdapter.enqueueDeletedMessage(") < expiry.index("_internal_deleteMessages(transaction:")
snapshot = adapter[adapter.index("static func enqueueDeletedMessage("):adapter.index("static func enqueueDeletedMedia(")]
assert snapshot.index("guard eligibility.isEligibleForLocalRetention") < snapshot.index("let snapshot = VeilgramArchivedMessage(")

print(
    "PASS: Veilgram archive hooks preserve pre-delete ordering and use the shared "
    f"eligibility contract ({delete_hook_count} delete hooks, {edit_hook_count} edit hooks)"
)
