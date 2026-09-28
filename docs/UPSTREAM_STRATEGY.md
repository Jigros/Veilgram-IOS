# Upstream strategy

- Base: [TelegramMessenger/Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS), candidate SHA `6ad963e5b62d354da79040f388ae2b9132fb17b8` (2026-07-17). Not yet imported or built in this repository.
- Keep `main` stable. Use `research/*`, `upstream/*`, `feature/*`, and `fix/*` branches with PRs.
- Import the exact upstream tree and submodule references after checking its repository instructions, license notices, binary dependencies and build configuration. Record source SHA, commit tree and submodule SHAs. Do not assert a pin until the import commit exists.
- First reproduce upstream simulator build with the specified toolchain, then brand and feature changes in separate PRs. Prefer isolated Veilgram targets and narrow, reviewed integration patches.
- For updates: fetch new upstream SHA; review release/versions.json and licensing; merge into an `upstream/*` branch; resolve conflicts by feature area; rerun baseline and two-account regression tests; update parity and release notes.
- Never replace a feature with a stale tweak patch without reading its code and verifying against the current upstream.
