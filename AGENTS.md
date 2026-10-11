# Repository working agreement

## Source and upstream

- `Jigros/Veilgram-IOS` is the sole product source of truth.
- `Jigros/Veilgram-Build` is CI-only and must not become a product-source mirror.
- The original upstream base is Telegram-iOS 12.9.2 at `6ad963e5b62d354da79040f388ae2b9132fb17b8`; the separate 13.0 integration candidate targets `f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838` and requires its own build and runtime acceptance.
- Preserve upstream history, submodule gitlinks, copyright notices and file-specific licenses. Do not replace an upstream merge with a flat source snapshot.

## Development policy

- Veilgram feature development is driven by the project roadmap and current task, not by inherited Telegram contribution policy.
- Experimental behavior may be implemented and tested in focused branches as long as the implementation is technically explicit, testable and does not expose credentials or private user data.
- Documentation about Telegram API terms, distribution or store-review risk is informational release context. It is not an implementation gate and must not be used to silently disable, stub out or omit Veilgram functionality.
- Keep development capability decisions separate from release/distribution decisions.
- If a feature is intentionally disabled for a particular build, represent that as an explicit build/runtime capability with a documented reason rather than an unconditional hidden guard.

## Change discipline

- Keep `main` stable. Use `research/*`, `upstream/*`, `feature/*`, `fix/*` and `cleanup/*` branches with focused pull requests.
- Isolate Veilgram-owned modules and keep patches to Telegram integration points narrow and documented.
- A passing checkout, project generation, dependency resolution, Bazel query or build start is not a passing compilation.
- Record exact source SHA, upstream SHA, environment, command, result and artifact/log hashes for build claims.

## Privacy and secrets

- Never commit real `api_id`, `api_hash`, sessions, auth keys, phone numbers, Apple certificates, profiles, private keys, passwords or signing secrets.
- Use `.veilgram-private/` for local configuration and GitHub encrypted secrets only when a workflow genuinely requires them.
- Use GitHub noreply commit identities for project-authored commits.
- Inspect staged changes and repository history for secrets and personal data before every publication or visibility change.
