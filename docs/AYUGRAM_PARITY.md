# AyuGram parity inventory and Veilgram implementation status

This table tracks technical implementation state in the Veilgram runtime branch. Release/distribution policy is intentionally tracked separately and does not change whether a feature is implemented.

| Feature | Veilgram status | Current Veilgram implementation |
|---|---|---|
| Suppress message read receipts | IMPLEMENTED | `SynchronizePeerReadState.swift` consults `VeilgramGhostModeRuntimePreferences` for ordinary cloud chats. |
| Suppress story views | IMPLEMENTED | `ManagedSynchronizeViewStoriesOperations.swift` and story engine paths suppress synchronization per account; device verification remains open. |
| Suppress online / force offline | IMPLEMENTED | `ManagedAccountPresence.swift` maps the effective presence to offline while the setting is enabled. |
| Suppress typing/send activities | IMPLEMENTED | `ManagedLocalInputActivities.swift` suppresses typing, recording, upload and group-call speaking activity while Ghost Mode activity suppression is enabled. |
| Manual/read-on-interaction mode | IMPLEMENTED | Per-account read-on-interaction setting controls automatic cloud read-state updates. |
| Delayed scheduled send | IMPLEMENTED_PARTIAL | Per-account Off/30s/60s/5min choice wraps current-text sends with review, then uses the upstream scheduled queue. Recordings, forwards, bots, ephemeral commands, edits and suggested posts keep their existing paths. New CI/device gate pending. |
| Warn before opening story | IMPLEMENTED | Story-open warning is integrated with Ghost Mode and the effective story-view preference. |
| Persistent deleted message archive | IMPLEMENTED | Batched writer with lifecycle flush/retry and serialized clear/import; ordinary delete, history-validation and min-available/range paths are covered. |
| Edit history | IMPLEMENTED | Previous text/entity revisions are captured on edit and exposed in Veilgram UI. |
| Media preservation and prefetch | IMPLEMENTED_PARTIAL | Already-local MediaBox bytes are copied into account-scoped protected storage with quota and cleanup; previews are available. Network prefetch is not implemented. |
| View deleted/search | IMPLEMENTED | Archive search, per-chat filtering, peer/message navigation and inline Deleted/Edited history are integrated. |
| Filters: regex, per-chat/global, reverse, exclusions | IMPLEMENTED | Local filter engine, persistence and chat rendering integration are present. |
| Hide blocked users/reactions/typing/member list | NOT_STARTED | No unified Veilgram implementation yet. |
| Restricted/deleted forwarding helpers | NOT_STARTED | No Veilgram-specific forwarding implementation yet. |
| Remove/collapse ads and sponsored posts | IMPLEMENTED | Shared render decision unifies classifier/sponsored collapse and reveal; stable grouping/scroll tests pass. Real-account ad-object verification remains open. |
| Local Premium UI | IMPLEMENTED | Effective local presentation state is per-account, with server entitlement consumers separated; presentation boundary checks pass. |
| Peek Online | IMPLEMENTED | Temporary online presence is available from Ghost Mode settings. |
| Banned/kicked chat cache | NOT_STARTED | No Veilgram implementation yet. |
| Expire button / capture controls | RESEARCHING | Platform-specific behavior still needs integration work. |
| Import/export archive and filters | IMPLEMENTED | Versioned local transfer envelopes and Veilgram UI exist. |
| Message Shot | IMPLEMENTED | Single-message context menu renders the selected message view and opens the system share sheet. |
| Similar-channel controls / folder counters / send confirmations | IMPLEMENTED_PARTIAL | Per-account current-message send confirmation is implemented; similar-channel controls and folder counters remain open. |
| Alternate icon picker | BLOCKED_BY_MISSING_ARTWORK | Application binding currently exposes no alternate icons; Veilgram-owned variants need packaging and UI exposure. |
| Streamer/capture privacy mode | IMPLEMENTED | AppDelegate covers the app while iOS reports active screen recording or mirroring; settings toggle is integrated. |
| Translator / Swiftgram extras | RESEARCHING | Not yet integrated into Veilgram runtime. |

## Status meanings

- **IMPLEMENTED** — runtime code is integrated in this branch.
- **IMPLEMENTED_PARTIAL** — usable runtime code exists but known paths or UX are incomplete.
- **CORE_ONLY** — data model/engine exists without complete runtime integration.
- **SEPARATE_BRANCH** — implementation exists elsewhere but is not part of this branch.
- **NOT_STARTED** — no Veilgram runtime implementation identified.
- **RESEARCHING** — design/source investigation is active.
- **BLOCKED_BY_MISSING_ARTWORK** — technical binding exists but required Veilgram-owned assets are absent.

Compilation status and device-test status are tracked separately from feature status.

## Verified integration gate

Runtime source `6f98453a8787eee8711862832459938096e0a196` passed both Swift/source tests and the full iOS simulator compile in [Actions run #85](https://github.com/Jigros/Veilgram-IOS/actions/runs/37008158360). The delayed-send changes following that source require a new gate; this prior PASS does not validate them.

Delayed send: Veilgram Settings → Delayed send → Off / 30 seconds / 1 minute / 5 minutes. Sending current text presents Cancel, Send and Schedule actions. Scheduled messages can be edited, sent immediately or deleted using the upstream Scheduled Messages screen. Cancel before scheduling preserves the composer. Scheduling uses the server queue and survives closing the app. Physical-device checks should cover cancellation, reply/entities/effects, silent sends, paid-message prompts, app restart and delivery timing.
