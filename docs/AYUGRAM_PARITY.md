# AyuGram parity inventory and Veilgram implementation status

This table tracks technical implementation state in the Veilgram runtime branch. Release/distribution policy is intentionally tracked separately and does not change whether a feature is implemented.

| Feature | Veilgram status | Current Veilgram implementation |
|---|---|---|
| Suppress message read receipts | IMPLEMENTED | `SynchronizePeerReadState.swift` consults `VeilgramGhostModeRuntimePreferences` for ordinary cloud chats. |
| Suppress story views | NOT_STARTED | No Veilgram runtime hook identified yet. |
| Suppress online / force offline | IMPLEMENTED | `ManagedAccountPresence.swift` maps the effective presence to offline while the setting is enabled. |
| Suppress typing/send activities | IMPLEMENTED_PARTIAL | `ManagedLocalInputActivities.swift` suppresses normal input activities; group-call speaking remains a separate path. |
| Manual/read-on-interaction mode | NOT_STARTED | No separate manual-read controller yet. |
| Delayed scheduled send | NOT_STARTED | No Veilgram-specific runtime integration yet. |
| Warn before opening story | NOT_STARTED | No Veilgram-specific story-open warning yet. |
| Persistent deleted message archive | IMPLEMENTED_PARTIAL | Ordinary cloud-message delete paths snapshot into Veilgram local storage and retained rows can remain visible. Range/min-available coverage is incomplete. |
| Edit history | IMPLEMENTED | Previous text/entity revisions are captured on edit and exposed in Veilgram UI. |
| Media preservation and prefetch | CORE_ONLY | Media archive models/store metadata exist, but a complete runtime MediaBox-byte copy pipeline is still missing. |
| View deleted/search | IMPLEMENTED_PARTIAL | Veilgram local archive screens expose retained records; richer per-chat search/navigation remains incomplete. |
| Filters: regex, per-chat/global, reverse, exclusions | IMPLEMENTED | Local filter engine, persistence and chat rendering integration are present. |
| Hide blocked users/reactions/typing/member list | NOT_STARTED | No unified Veilgram implementation yet. |
| Restricted/deleted forwarding helpers | NOT_STARTED | No Veilgram-specific forwarding implementation yet. |
| Remove/collapse ads and sponsored posts | IMPLEMENTED_PARTIAL | Ordinary channel-ad heuristics and sponsored-message collapse/reveal exist; render paths still need consolidation. |
| Local Premium UI | SEPARATE_BRANCH | `feature/local-premium-ui` contains a preference core, but it is not integrated into this runtime branch. |
| Peek Online | NOT_STARTED | No Veilgram implementation yet. |
| Banned/kicked chat cache | NOT_STARTED | No Veilgram implementation yet. |
| Expire button / capture controls | RESEARCHING | Platform-specific behavior still needs integration work. |
| Import/export archive and filters | IMPLEMENTED | Versioned local transfer envelopes and Veilgram UI exist. |
| Message Shot | NOT_STARTED | No Veilgram implementation yet. |
| Similar-channel controls / folder counters / send confirmations | NOT_STARTED | No Veilgram-specific integration yet. |
| Alternate icon picker | BLOCKED_BY_MISSING_ARTWORK | Application binding currently exposes no alternate icons; Veilgram-owned variants need packaging and UI exposure. |
| Streamer/capture privacy mode | RESEARCHING | iOS-specific implementation remains open. |
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
