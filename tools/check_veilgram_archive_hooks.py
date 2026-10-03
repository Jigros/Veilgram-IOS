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

print(
    "PASS: Veilgram archive hooks preserve pre-delete ordering and use the shared "
    f"eligibility contract ({delete_hook_count} delete hooks, {edit_hook_count} edit hooks)"
)
