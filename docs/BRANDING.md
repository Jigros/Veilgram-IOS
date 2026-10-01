# Veilgram BUILD-1 branding

Status: **NixOS static source checks passed; branded iOS compilation has NOT run**. Branch `feature/branding` is based on unmerged foundation PR #17.

## Scope

- Bazel `Telegram/BUILD`: Veilgram bundle display/name for app and related extensions, without renaming upstream module and executable targets.
- All `Telegram/Telegram-iOS/*.lproj/InfoPlist.strings`: unique Veilgram display-name entries, preserving native-language permission texts.
- `build-system/veilgram-development.example.json`: compile-safe placeholders, no usable API credentials.
- The unique `bundle_id` must be chosen by the developer; the example ID is not production-ready. Real Telegram API credentials must be obtained privately from `my.telegram.org/apps`.
- Keep original Telegram upstream history and notices unchanged.

## BUILD-1 acceptance checks

- [x] GitHub source inspection: all 19 existing localized InfoPlist.strings each contain exactly one `CFBundleDisplayName = "Veilgram"` entry. Executable checker passed on NixOS; not an iOS compilation.
- [ ] Independent Veilgram artwork replaces the Telegram logo in every icon variant and size before any release/distribution.
- [ ] Compile actual branded source commit on macOS 26/Xcode 26.2/Bazel 8.4.2, `debug_sim_arm64`.
- [ ] Inspect embedded app Info.plist, localized strings, extension names and entitlements in the resulting IPA.
- [ ] Verify simulator startup, URL handling and unique bundle identity.
- [ ] Real-device signing, pushes and login are separately verified before claiming them supported.

## CI trust boundary

Public `Jigros/Veilgram-Build` only builds unchanged public upstream. It cannot build the private Veilgram feature branch without a separately reviewed minimal-privilege source access mechanism. Never mirror private code or paste a broad PAT into public workflows. The NixOS machine performed static checks at commit `faa1a451f098b53cc2e4ee8b2efec48b29df655b` with clean working tree: `python3 -m py_compile tools/check_veilgram_branding.py`, `python3 -m json.tool build-system/veilgram-development.example.json`, `git diff --check` against the foundation, and `python3 tools/check_veilgram_branding.py` (PASS: Bazel bundle names, 19 localized labels, config placeholders). NixOS checks cannot certify Xcode compilation.

## Branding and feature scope

Branding validation is independent from Veilgram runtime feature development. Ghost Mode, sponsored-message handling, archive behavior and other runtime features may evolve on their own branches while branding checks continue. Distribution considerations are recorded separately and are not an implementation gate.

## IPA identity gate (introduced after initial static audit)

After building a **real branded simulator IPA** on an authorized macOS runner, copy only that artifact to a trusted location and execute:

```sh
python3 tools/verify_build1_ipa.py path/to/build1-simulator.ipa \
  --bundle-id YOUR_ACTUAL_INDEPENDENT_BUNDLE_ID \
  --report build1-identity-report.json
```

The verifier uses only the Python standard library and refuses placeholder or Telegram-owned bundle IDs. It checks the single app's `CFBundleIdentifier`, `CFBundleName`, `CFBundleDisplayName`, included localized display names, and embedded extension identifiers and names; outputs an IPA SHA-256 and structured problem list. Keep artifact paths and personal credentials out of public reports.

On NixOS the script passed `py_compile`; a synthetic valid IPA passed and a synthetic app named Telegram failed as expected. **No real BUILD-1 IPA was present**, so the real IPA gate, code signing, extensions' functionality, simulator launch, visual assets, and entitlements are still unverified. Do not count synthetic fixture tests as successful compilation.

## BUILD-1 CI checkout evidence — 2026-09-30

- [First public BUILD-1 run 36706226051](https://github.com/Jigros/Veilgram-IOS/actions/runs/36706226051) **FAILED before compilation** in checkout: the unchanged upstream `.gitmodules` uses `../tgcalls.git` and `../rlottie.git`; in standalone `Jigros/Veilgram-IOS` these resolve to nonexistent `Jigros/tgcalls` and `Jigros/rlottie`.
- The remediation keeps tracked `.gitmodules` and the pinned gitlinks unchanged. CI first checks out without submodules, overrides the two URLs locally to `TelegramMessenger/tgcalls` and `TelegramMessenger/rlottie`, then runs `git submodule update --init --recursive` and records status. Both official destinations were independently reachable during remote check.
- [Second BUILD-1 run 36707107223](https://github.com/Jigros/Veilgram-IOS/actions/runs/36707107223) was dispatched with the fix. **No compilation success can be claimed until this run completes and its IPA is validated.**