# Veilgram agent rules

GitHub `Jigros/Veilgram-IOS` is the source of truth. Inspect branch, HEAD, working tree, repository instructions and current upstream before edits. Never push feature work directly to `main`; use a branch and PR. Keep claims in README and `docs/AYUGRAM_PARITY.md` aligned with actual tests. Search, read, understand, plan, modify, test, commit and report evidence.

For the owner's NixOS machine, use Remote Desktop Commander and temporary `nix develop`/`nix shell` environments. Linux cannot certify an iOS build. Read the pinned `versions.json` and use compatible macOS/Xcode/Bazel for real simulator or device builds. Do not claim build success without target completion and logs.

Never commit API credentials, sessions, signing secrets or user data. Preserve licenses and notices. Prefer small, reviewed hooks and isolated Veilgram modules; verify off-state upstream behavior and actual network effects with a second test account. If requirements are blocked, record exact evidence and keep status BLOCKED or RESEARCHING rather than calling them complete.
