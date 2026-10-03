# Contributing to Veilgram

This repository is a Veilgram product fork based on Telegram-iOS. Veilgram accepts focused feature work, UI changes, fixes, refactors, research prototypes and documentation updates when they fit the project roadmap and preserve repository hygiene.

Telegram's upstream contribution rules do not govern what Veilgram may implement. When a change is intended for upstream Telegram-iOS, follow Telegram's own contribution policy in that upstream repository.

## What contributions are accepted

Veilgram accepts, among other things:

- new Veilgram features and settings;
- user-interface changes;
- privacy and local-data features;
- performance and build-system improvements;
- bug fixes and refactors;
- tests, diagnostics and documentation.

Keep experimental features explicit. If something is disabled for a specific build or release, use a visible capability/configuration switch rather than a hidden no-op, unconditional `return`, or documentation-only prohibition.

## Build instructions

See the repository build documentation for the currently supported Veilgram configuration and toolchain. Build claims must identify the exact source commit, configuration and result.

## Pull upstream changes into the fork deliberately

Telegram-iOS advances quickly. Import upstream changes with preserved history and review conflicts against Veilgram integration points before merging them.

Avoid blind rebases that drop Veilgram-owned patches. Prefer a traceable upstream integration branch/merge strategy consistent with `AGENTS.md`.

## Pull request guidelines

### Keep pull requests focused

Keep changes reviewable and make cross-cutting changes only when the feature genuinely requires them. Avoid unrelated whitespace or formatting churn.

### Keep code clear

Use descriptive names, strong types and explicit error handling. Do not hide functional failures behind empty `catch` blocks or silent fallback behavior unless the fallback is intentional and observable.

### Test changes

Run the narrowest relevant tests first, then the supported Veilgram build validation for changes that affect application targets. Record the commands and results in the pull request.

### Write useful commit messages

Explain what changed and why. Mention important integration points, migration behavior and user-visible effects. Reference issues when applicable.
