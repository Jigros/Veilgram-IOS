#!/usr/bin/env python3
from pathlib import Path

state = Path("submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift").read_text()
adapter = Path("submodules/TelegramCore/Sources/State/VeilgramArchiveStateAdapter.swift").read_text()

assert state.count("VeilgramArchiveStateAdapter.enqueueDeletedMessage") == 2, "expected exactly two accepted delete hooks"
assert state.count("VeilgramArchiveStateAdapter.enqueuePreviousEditRevision") == 1, "expected exactly one accepted edit hook"

global_case = state.index("case let .DeleteMessagesWithGlobalIds(ids):")
global_delete = state.index("transaction.deleteMessagesWithGlobalIds", global_case)
global_hook = state.index("VeilgramArchiveStateAdapter.enqueueDeletedMessage", global_case)
assert global_hook < global_delete, "global-id snapshot must happen before Postbox deletion"

direct_case = state.index("case let .DeleteMessages(ids):")
direct_delete = state.index("_internal_deleteMessages", direct_case)
direct_hook = state.index("VeilgramArchiveStateAdapter.enqueueDeletedMessage", direct_case)
assert direct_hook < direct_delete, "MessageId snapshot must happen before Postbox deletion"

min_case = state.index("case let .UpdateMinAvailableMessage")
next_case = state.find("\n            case ", min_case + 1)
min_segment = state[min_case: next_case if next_case != -1 else len(state)]
assert "VeilgramArchiveStateAdapter" not in min_segment, "min-available retention is out of scope"

required_adapter_guards = [
    "Namespaces.Peer.SecretChat",
    "Namespaces.Message.Cloud",
    "viewOnceTimeout",
    "minAutoremoveOrClearTimeout",
    "EphemeralMessageAttribute",
    "EphemeralOutgoingMessageAttribute",
    "eligibility.isEligibleForLocalRetention",
]
for guard in required_adapter_guards:
    assert guard in adapter, f"missing archive eligibility guard: {guard}"

for path in [
    "submodules/TelegramCore/Sources/State/ManagedAutoremoveMessageOperations.swift",
    "submodules/TelegramCore/Sources/SecretChats/ProcessSecretChatIncomingDecryptedOperations.swift",
]:
    p = Path(path)
    if p.exists():
        assert "VeilgramArchiveStateAdapter" not in p.read_text(), f"forbidden archive hook in {path}"

print("PASS: Veilgram archive hooks remain limited to accepted ordinary cloud edit/delete paths")
