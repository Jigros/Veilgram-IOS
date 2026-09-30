# VeilArchive architecture research — no runtime feature shipped

Status: **RESEARCH ONLY**. No Anti-Delete, edit-history, media capture or deletion interception code exists in this branch. This document is not a decision to ship features that conflict with Telegram privacy expectations or API Terms.

## Source-level event map (official Telegram-iOS 12.9.2 at pinned upstream)

- `submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift`: `updateDeleteChannelMessages` maps channel IDs to `updatedState.deleteMessages`; `updateDeleteMessages` calls `updatedState.deleteMessagesWithGlobalIds`. PTS/reorder/hole handling occurs before application; storing every raw delete update would double count and incorrectly preserve rejected events.
- Same file `updateEditMessage`: converts `Api.Message` into `StoreMessage`, calls `updatedState.editMessage`. The existing Postbox message version must be read **before** accepted edit replacement for any edit-history snapshot.
- Same file's state apply: `.DeleteMessagesWithGlobalIds` calls `transaction.deleteMessagesWithGlobalIds` and reclaims referenced cached media; `.DeleteMessages` uses `_internal_deleteMessages`.
- `submodules/TelegramCore/Sources/TelegramEngine/Messages/DeleteMessages.swift`: `_internal_deleteMessages` handles message indexes and media-resource cleanup. Modifying Postbox removal to retain deleted rows would violate upstream invariants and is **not** the proposed design.
- `ManagedAutoremoveMessageOperations.swift`, `ProcessSecretChatIncomingDecryptedOperations.swift` and `UpdateMinAvailableMessage` are separate deletion paths, **out of scope** for preservation.

## Proposed strict scope — pending privacy/product decision

1. **Off by default.** Explicit in-app consent and explain what ordinary cloud-message history is kept locally.
2. Initially consider only ordinary non-secret, non-ephemeral cloud messages that were *already present on the device*. Never fetch remote content specifically to evade deletion or retention policy.
3. Keep a distinct versioned store, not Telegram Postbox. Never inject an archived message back into live conversation/search as though the server still has it.
4. Never capture secret chats, self-destructing/TTL media, ephemeral stories, view-once content, revoked authentication data, private keys or password state. Honor account removal and `Clear local archive` immediately.
5. No additional backend, uploads, cloud synchronization, notification payload logging, screenshots, auto-export or silent external sharing. Keep an explicit quota and retention period.
6. Restrict archive read/write by account identity. Use an app-private protected directory (file-protection class appropriate for lock-state behavior); avoid copying credential keys into archive DB. Review encryption and backup exclusion before release.
7. Keep separate **message snapshot**, **edit revision** and **media availability** records, including provenance (`locally-observed`), message peer namespace, message ID, revision time and missing-media marker. A missing media byte stream must never be represented as a saved playable file.
8. Re-validate Telegram API terms and privacy tradeoffs, legal requirements and user expectations **before implementing or distributing** any ordinary-message retention. Passing build tests alone does not authorize this behavior.

## Architecture gates and tests

- [ ] Written product/compliance decision defining permitted message types, storage and retention.
- [ ] Offline schema design with migration/rollback, file-size quotas and recoverable crash writes.
- [ ] Dedicated data store module with unit tests independent of Telegram UI.
- [ ] Narrow event integration only after verifying accepted PTS state transitions and testing duplicates/out-of-order updates.
- [ ] Two-account isolation, deleted-account cleanup, restart persistence, backup exclusion, opt-out purge and no-secret-chat tests.
- [ ] Real-device file-protection and storage-pressure tests; ensure upstream messaging and media cleanup are unaffected when disabled.
- [ ] Native archive UI distinguishes current server messages from historical local snapshots.
- [ ] Tests with actual accounts and bounded fixture data, without real personal messages committed to public Git.

## Explicit non-goals

Ghost Mode/read-status tampering, suppressing typing/online status, hiding official sponsored messages, preserving self-destructing content, bypassing protected-content restrictions, and representing client-side flags as Telegram server entitlements.

Research evidence only, no user-visible archive feature is implemented.
