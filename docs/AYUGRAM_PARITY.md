# AyuGram parity inventory and Veilgram implementation status

This table tracks technical implementation state in the Veilgram runtime branch. Release/distribution policy is intentionally tracked separately and does not change whether a feature is implemented.

| Feature | Veilgram status | Current Veilgram implementation |
|---|---|---|
| Suppress message read receipts | IMPLEMENTED | `SynchronizePeerReadState.swift` consults `VeilgramGhostModeRuntimePreferences` for ordinary cloud chats. |
| Suppress ordinary content receipts | IMPLEMENTED_PARTIAL | Queued ordinary cloud content receipts are filtered before user/group/channel RPCs and dropped without replay; expiring-media protocol behavior remains upstream. Source checks and Swift parse pass; macOS runtime/compile and device verification pending (#4). |
| Suppress story views | IMPLEMENTED | `ManagedSynchronizeViewStoriesOperations.swift` and story engine paths suppress synchronization per account; device verification remains open. |
| Suppress online / force offline | IMPLEMENTED | `ManagedAccountPresence.swift` maps the effective presence to offline while the setting is enabled. |
| Suppress typing/send activities | IMPLEMENTED | `ManagedLocalInputActivities.swift` suppresses typing, recording, upload and group-call speaking activity while Ghost Mode activity suppression is enabled. |
| Manual/read-on-interaction mode | IMPLEMENTED_PARTIAL | Opening/scrolling and new arrivals are gated with live preferences. Immediate accepted composer sends and generic sends read the visible range; canceled, rejected and scheduled sends do not. Accepted ordinary and Stars reactions now trigger the explicit read; story-reply/media entry points and device matrix remain open (#4). |
| Native scheduled / repeating send | UPSTREAM_IMPLEMENTED_VERIFY | Native long-press send menu, schedule picker and server queue. Repeating sends use the real account Premium status. Custom delay preference/modal removed; fresh compile and physical-device matrix pending (#50). |
| Warn before opening story | IMPLEMENTED | Story-open warning is integrated with Ghost Mode and the effective story-view preference. |
| Persistent deleted message archive | IMPLEMENTED | Batched writer with lifecycle flush/retry and serialized clear/import; ordinary delete, history-validation and min-available/range paths are covered. |
| Edit history | IMPLEMENTED | Previous text/entity revisions are captured on edit and exposed in Veilgram UI. |
| Media preservation and prefetch | IMPLEMENTED_PARTIAL | Already-local MediaBox bytes are copied into account-scoped protected storage with quota and cleanup; previews are available. Network prefetch is not implemented. |
| View deleted/search | IMPLEMENTED | Archive search, per-chat filtering, peer/message navigation and inline Deleted/Edited history are integrated. |
| Filters: regex, per-chat/global, reverse, exclusions | IMPLEMENTED | Local filter engine, persistence and chat rendering integration are present. |
| Hide blocked users/reactions/typing/member list | NOT_STARTED | No unified Veilgram implementation yet. |
| Restricted/deleted forwarding helpers | NOT_STARTED | No Veilgram-specific forwarding implementation yet. |
| Remove/collapse ads and sponsored posts | IMPLEMENTED | Shared render decision unifies classifier/sponsored collapse and reveal; stable grouping/scroll tests pass. Real-account ad-object verification remains open. |
| Local Premium UI | IMPLEMENTED_PARTIAL | Per-account presentation state drives live theme and alternate-icon availability, account-local note links and self-profile badge/title styling. Other visual components, animated self-avatars and usable alternate icon artwork remain open (#11); real entitlement is preserved. |
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

Runtime source `6f98453a8787eee8711862832459938096e0a196` passed both Swift/source tests and the full iOS simulator compile in [Actions run #85](https://github.com/Jigros/Veilgram-IOS/actions/runs/37008158360). Changes following that source require a new gate; this prior PASS does not validate them.

Native scheduled send: hold the Send button and select the upstream Schedule Message action. Use the native date/time picker, send-when-online option where available, and Repeat with a real Premium account. The server stores the schedule; the upstream Scheduled Messages screen supports edit, reschedule, send now and delete. There is no Veilgram fixed-delay preference or alternate send modal. Verify text, media, recordings, replies/entities/effects, silent sends, paid-message handling, cancellation, restart and delivery on a physical device. Local Premium must not unlock server repeat entitlement.

## Ghost interaction boundaries

Read-on-interaction keeps ordinary chat opening and scrolling from automatically advancing read state. An accepted immediate send through the composer or generic controller send path and accepted ordinary/Stars reactions explicitly read the visible range. It does not acknowledge a canceled confirmation, slowmode rejection or future schedule. The independent Hide read receipts setting remains authoritative: turning on read-on-interaction does not override full read suppression. Ordinary voice/video content receipts are filtered at queued-operation dispatch, including previously queued receipts; suppressed operations are removed rather than deferred until Ghost is disabled. Secret and expiring-media protocol actions remain upstream-owned.

Sending, reacting, replying to stories, requests for transcription and other server operations are visible actions. Ghost does not make the sender anonymous or hide content delivered to the server. Reply-thread/direct-read paths, other interaction triggers, account switching, reconnect/retry and second-client observations remain explicit acceptance work in #4.

## Follow-up Ghost receipt coverage

The direct/bulk receipt follow-up covers six explicit forum/monoforum read RPCs, pending mention and reaction/poll acknowledgements, viewing live locations, bulk mention/reaction/poll clear operations and the network mark-all-chats path. Normal per-message local state is completed without fabricating server PTS; pending actions are removed rather than replayed later. Existing mark-all mention/reaction/poll transactions already update local tags and summaries before network operations are queued. Explicit local Mark all chats read remains in the interactive read API; the separate server unread-mark sweep does not send readHistory while Ghost suppression is enabled. Expiring-media protocol exceptions remain in the per-message receipt policy.

Run #90 fully compiled source `75237a77d608174a600201271864f660a3b1e0d7`; see BUILD_GATE_90.md for command, environment and artifact digest. Follow-up code has passed the 11 source regressions and Swift parse; new complete build/device gates remain required.
