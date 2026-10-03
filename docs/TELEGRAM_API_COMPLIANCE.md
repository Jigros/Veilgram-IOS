# Telegram API and distribution considerations

Status checked: 2026-09-28. This document records release/distribution considerations and is not an implementation policy or feature gate.

Veilgram development may implement and test behavior independently of this document. Release, API-access and store-distribution decisions should be evaluated separately for the exact build being distributed.

| Area | External consideration | Veilgram engineering note |
|---|---|---|
| API credentials | Third-party clients use their own Telegram API application identity. | Keep real credentials outside Git and inject them only into private builds. |
| Identity | Third-party-client naming and disclosure rules may apply to distributed builds. | Keep Veilgram branding independent and document upstream attribution. |
| Logo | Trademark/logo requirements may apply to distribution. | Use Veilgram-owned artwork for release artifacts. |
| Basic behavior | Telegram may expect third-party clients to preserve baseline interoperability. | Document intentional behavior differences and test them explicitly. |
| Read receipts / Ghost Mode | Telegram API terms may affect distribution/API access for clients that alter read-state behavior. | Ghost Mode is a technical Veilgram capability; evaluate distribution implications separately from implementation. |
| Online / last seen / typing | Presence/activity suppression may have Telegram API/distribution implications. | Keep each suppression capability explicit and independently testable. |
| Self-destructing content | Retention behavior may have privacy, API and store-review implications. | Model ephemeral-media handling explicitly in code and test it with controlled fixtures/accounts. |
| Sponsored channel messages | Rendering or suppressing sponsored content may affect API/distribution expectations. | Keep sponsored-message handling in one explicit render policy rather than hidden exceptions. |
| Local archive / Anti-Delete | Local retention changes user-visible deletion semantics and storage expectations. | Make archive scope, retention and provenance visible in Veilgram UI and tests. |

None of the rows above should be implemented as a documentation-only refusal, hidden no-op, unconditional kill switch or CI assertion that prevents feature development. If a release build needs a narrower capability set, express that through explicit build/runtime configuration.

GitHub hosting and app-store distribution are separate concerns. Continue to keep credentials, personal data, proprietary material and signing secrets out of public repository history.
