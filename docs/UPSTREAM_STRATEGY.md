# Upstream strategy

- Base: [TelegramMessenger/Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS), BUILD-0 verified SHA `6ad963e5b62d354da79040f388ae2b9132fb17b8` (2026-07-17). Compiled unchanged in [public BUILD-0 run 36378626863](https://github.com/Jigros/Veilgram-Build/actions/runs/36378626863), but not yet imported into the private product repository.
- Keep `main` stable. Use `research/*`, `upstream/*`, `feature/*`, and `fix/*` branches with PRs.
- Preserve upstream Git history with an unrelated-history merge into a dedicated `upstream/telegram-12.9.2` branch, retaining the exact upstream parent SHA and gitlinks. Resolve README overlap by retaining Veilgram's status and documenting official build instructions separately. Record source SHA, tree and recursive submodule SHAs. GitHub connector cannot directly reference the upstream tree in this standalone repository (`422 Tree SHA does not exist`), so a bulk history transfer requires a Git transport path; do not substitute a flat snapshot.
- First reproduce upstream simulator build with the specified toolchain, then brand and feature changes in separate PRs. Prefer isolated Veilgram targets and narrow, reviewed integration patches.
- For updates: fetch new upstream SHA; review release/versions.json and licensing; merge into an `upstream/*` branch; resolve conflicts by feature area; rerun baseline and two-account regression tests; update parity and release notes.
- Never replace a feature with a stale tweak patch without reading its code and verifying against the current upstream.
