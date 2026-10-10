# Upstream strategy

## Pinned foundation

- Upstream: [TelegramMessenger/Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS)
- Telegram version: 12.9.2
- Exact upstream commit: `6ad963e5b62d354da79040f388ae2b9132fb17b8`
- Foundation branch: `upstream/telegram-12.9.2`
- Import merge commit: `08ade9d817cd1a3a7a4ad003b603d0f85319b3e7`
- Import tree: `3a45dd193b8fba459876c5de82914af1730ddda5`
- Product-history parent: `46684b07b9ef112b47c21cd331a8892ce01747be`
- Exact upstream parent: `6ad963e5b62d354da79040f388ae2b9132fb17b8`

As checked against the official upstream on 2026-10-09, this working tree is **not** on the latest Telegram iOS source: `release-13.0.0` and `master` point to `f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838` (`versions.json` app `13.0`, Xcode `26.6`, Bazel `9.2.0`). The pinned 12.9.2 import is 829 upstream commits behind that commit. Do not identify this branch as Telegram 13.0 or update `versions.json` without the actual history-preserving upstream import and clean BUILD-0 described below.

The import is a two-parent merge. It preserves upstream commit history and submodule gitlinks; it is not a flattened archive. At the import commit, comparison with the exact upstream tree contains only the Veilgram root `README.md` and the relocated official README at `docs/UPSTREAM_BUILD.md`.

This standalone repository is not represented by GitHub as a network fork. The preserved merge topology and the documented upstream remote are the maintainable synchronization mechanism.

## Update procedure

1. Select an exact official upstream commit; record Telegram version and release date.
2. Read `README.md`, `versions.json`, build tooling changes, submodule changes and license/notice changes at that exact commit.
3. Run a clean, unchanged upstream BUILD-0 with the required macOS, Xcode and Bazel versions.
4. Create `upstream/telegram-<version>` from current product `main`.
5. Fetch the selected commit from the official upstream remote and merge it with `--no-ff`. `--allow-unrelated-histories` was needed only for the first import.
6. Resolve conflicts narrowly. Retain Veilgram-owned documentation and branding while preserving upstream behavior, gitlinks, licenses and notices.
7. Verify the merge parents, exact upstream ancestry, recursive submodule SHAs and the diff against upstream.
8. Open a dedicated upstream-foundation PR. Do not mix branding or product features into it.
9. After review, rerun the appropriate baseline/build regression and record evidence before merging or releasing.

Never replace this process with a giant untracked copy, squashed vendor drop or second source-of-truth mirror.

## Downstream isolation

Prefer Veilgram-owned Bazel targets and modules. Changes inside Telegram-owned targets should be small integration hooks with a documented reason. Branding belongs in a separate layer and PR. Feature work starts only after BUILD-1 proves the branded foundation still compiles.
