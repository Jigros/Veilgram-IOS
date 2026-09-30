# Veilgram BUILD-1 branding

Status: **NixOS static source checks passed; branded iOS compilation has NOT run**. Branch `feature/branding` is based on unmerged foundation PR #17.

## Scope

- Bazel `Telegram/BUILD`: Veilgram bundle display/name for app and related extensions, without renaming upstream module and executable targets.
- All `Telegram/Telegram-iOS/*.lproj/InfoPlist.strings`: unique Veilgram display-name entries, preserving native-language permission texts.
- `build-system/veilgram-development.example.json`: compile-safe placeholders, no usable API credentials.
- The unique `bundle_id` must be chosen by the developer; the example ID is not production-ready. Real Telegram API credentials must be obtained privately from `my.telegram.org/apps`.
- Keep original Telegram upstream history and notices unchanged.

## BUILD-1 acceptance checks

- [x] GitHub source inspection: all 19 existing localized InfoPlist.strings each contain exactly one `CFBundleDisplayName = "Veilgram"` entry. The executable checker remains to be run in a checkout.
- [ ] Independent Veilgram artwork replaces the Telegram logo in every icon variant and size before any release/distribution.
- [ ] Compile actual branded source commit on macOS 26/Xcode 26.2/Bazel 8.4.2, `debug_sim_arm64`.
- [ ] Inspect embedded app Info.plist, localized strings, extension names and entitlements in the resulting IPA.
- [ ] Verify simulator startup, URL handling and unique bundle identity.
- [ ] Real-device signing, pushes and login are separately verified before claiming them supported.

## CI trust boundary

Public `Jigros/Veilgram-Build` only builds unchanged public upstream. It cannot build the private Veilgram feature branch without a separately reviewed minimal-privilege source access mechanism. Never mirror private code or paste a broad PAT into public workflows. The NixOS machine performed static checks at commit `faa1a451f098b53cc2e4ee8b2efec48b29df655b` with clean working tree: `python3 -m py_compile tools/check_veilgram_branding.py`, `python3 -m json.tool build-system/veilgram-development.example.json`, `git diff --check` against the foundation, and `python3 tools/check_veilgram_branding.py` (PASS: Bazel bundle names, 19 localized labels, config placeholders). NixOS checks cannot certify Xcode compilation.

## Distribution/API requirements

This is an unshippable branding draft until icon and attribution checks pass. Ghost Mode, suppression of sponsored ads, preserving self-destructing media and other behavioral work is deliberately absent: read `docs/TELEGRAM_API_COMPLIANCE.md` before expanding scope.
