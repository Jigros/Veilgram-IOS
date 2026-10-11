# Veilgram iPhone beta acceptance protocol

**Device-platform compilation is verified; real iPhone installation/login is not yet executed.** Current integration candidate: `43584f7f981292d1a8e4f6c80ac3fd895e2b602c` (Telegram iOS 13.0), Xcode 26.6/Bazel 9.2.0. Public CI uses fixture credentials; the private ARM64 build uses encrypted API inputs and emits an encrypted IPA. Real Telegram credentials stay private, and the user—not GitHub Actions—signs the candidate with their personal certificate using ESign/Feather.

## Artifact validation before handing off

- [x] Device-platform ARM64/iOS compilation has passed on the candidate (BUILD-12 run 36798755909).
- [x] The assembled icon-pruned IPA was audited again in BUILD-13 (run 36800258357).
- [ ] Record the exact private credential-bearing source SHA, target `debug_arm64` or `release_arm64`, Xcode, Bazel and IPA SHA256 before device handoff.
- [ ] Confirm `verify_device_ipa.py` PASS on the exact private IPA for ARM64 platform **iOS** (not simulator), including the app and every extension.
- [ ] Inspect `CFBundleIdentifier`, display name, `CFBundleURLTypes`, minimum iOS version and all `PlugIns/*.appex` identifiers.
- [ ] Document and remove fake build-time profiles from installed output; users must not rely on self-signed fixtures for actual installation.
- [ ] Replace the remaining primary Telegram icon references before any release candidate. BUILD-13 removed inherited alternate icons but still reports primary-icon references.
- [ ] Ensure the installed binary/report does not leak API credentials, team IDs, real phone numbers, signing certificates, sessions, developer hostnames or personal values.

## Private API identity

Public CI stays fixture-only. For a private login-capable build, use `.veilgram-private/API_KEYS` and `tools/prepare_telegram_api_config.py --source external` as documented in `docs/API_IDENTITY.md`. The generated JSON and any IPA compiled with real credentials must remain private; do not attach them to Actions, PRs, issues or screenshots.

## User-side signing (not performed by CI)

1. Use an **actual device** IPA only after the exact private artifact passes device verification. Never use a simulator IPA for phone installation.
2. In ESign/Feather choose the user's own certificate and provisioning profile; re-sign the host app **and** all app extensions, with mutually compatible identifiers/entitlements. Do not send signing material to this repository or any issue comment.
3. Capabilities depend on the user's account/profile. Push notifications, associated domains, app groups, Siri, widgets and extension behavior may differ or fail when re-signed. Re-signing cannot grant missing entitlements.
4. Keep app identifiers stable across updates; test clean install first, then update in place. A different ID creates a separate installation and may not migrate local data.
5. Do not post screenshots containing login codes, phone numbers, tokens or personal conversations.

## Manual functional test plan

| Gate | Method | Current state |
|---|---|---|
| Fresh installation | Install user-signed device IPA, ensure launch without crash | NOT TESTED |
| Cold start | Force-close, reboot phone, relaunch | NOT TESTED |
| Login | Build privately with external Telegram API credentials and authenticate on-device | READY FOR PRIVATE TEST |
| Chat baseline | Send/receive text/media, attach image and file, search, notifications | NOT TESTED |
| Multiple accounts | Switch, log out, ensure isolated local settings | NOT TESTED |
| Veilgram entry | Settings > Veilgram, navigate back, verify local-feature settings persist | NOT TESTED |
| Extensions | Share sheet, widgets, notification service if allowed by signing | NOT TESTED |
| UI | Dark/light, Dynamic Type, VoiceOver and language | NOT TESTED |
| Storage/privacy | No user data in CI or reports, clean removal on logout | NOT TESTED |
| Update | Install next signed build with matching identifier; check no data loss | NOT TESTED |

Do not mark a gate PASS based only on successful compilation, IPA extraction or fake-profile validation. Record reproducible bugs without exposing account data. For ephemeral, secret or otherwise sensitive-media behavior, use controlled test accounts/fixtures and record the exact capability being exercised without publishing private content.