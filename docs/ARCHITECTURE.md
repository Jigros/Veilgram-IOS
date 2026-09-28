# Veilgram architecture (research decision)

Provisional base: official [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) at `6ad963e5b62d354da79040f388ae2b9132fb17b8`. BUILD-0 passed for this unmodified upstream in the public build-only repository; this does not verify a Veilgram branch build. Swiftgram at `cf8b23beaaac4126a396337ac2d5be13f9f76b66` is a reference for existing iOS behavior. Do not transplant its whole tree without license and merge review.

Proposed boundaries: small, documented hooks at TelegramCore network/read, update processing, and UI integration points; separate Veilgram settings, archive, filters and UI modules where Bazel target layout permits. An account-scoped SQLite archive is a candidate, not a finalized implementation. It must use versioned migrations, a distinct storage lifecycle from Telegram cache, explicit export/import without keys, and bounded media retention. Archived records must not masquerade as server messages.

BUILD-0 is clean upstream compilation on macOS/Xcode. BUILD-1 is branding and an installable test build. Only then integrate archive and Ghost behavior incrementally. Network behavior must be verified with a second account; UI state alone is insufficient.

Open design risks: multi-account isolation, secret chat handling, protected/ephemeral media, background delivery and missing messages while iOS app is suspended, rate limiting, server-side visibility on replies/reactions/sends, and cache cleanup. Each is a documented acceptance test before marking WORKING.
