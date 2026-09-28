# Repository working agreement

## Source and upstream

- `Jigros/Veilgram-IOS` is the sole product source of truth.
- `Jigros/Veilgram-Build` is CI-only and must not become a product-source mirror.
- The current upstream base is Telegram-iOS 12.9.2 at `6ad963e5b62d354da79040f388ae2b9132fb17b8`.
- Preserve upstream history, submodule gitlinks, copyright notices and file-specific licenses. Do not replace an upstream merge with a flat source snapshot.

## Phase gates

- BUILD-0 passed only for unchanged official upstream.
- Keep this foundation PR free of branding and Veilgram features.
- Implement branding alone on `feature/branding`, then require a real BUILD-1 compilation before feature work.
- After BUILD-1, the first planned functional research area is VeilArchive and Anti-Delete. Ghost Mode is not first.
- Read `docs/TELEGRAM_API_COMPLIANCE.md` before any behavior-changing feature. Do not claim or ship behavior prohibited by the Telegram API Terms without an explicit recorded product/legal decision.

## Change discipline

- Keep `main` stable. Use `research/*`, `upstream/*`, `feature/*` and `fix/*` branches with focused pull requests.
- Isolate Veilgram-owned modules and keep patches to Telegram integration points narrow and documented.
- A passing checkout, project generation, dependency resolution, Bazel query or build start is not a passing compilation.
- Record exact source SHA, upstream SHA, environment, command, result and artifact/log hashes for build claims.

## Privacy and secrets

- Never commit real `api_id`, `api_hash`, sessions, auth keys, phone numbers, Apple certificates, profiles, private keys, passwords or signing secrets.
- Use `.veilgram-private/` for local configuration and GitHub encrypted secrets only when a workflow genuinely requires them.
- Use GitHub noreply commit identities for project-authored commits.
- Inspect staged changes and repository history for secrets and personal data before every publication or visibility change.
