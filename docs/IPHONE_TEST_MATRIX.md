# Veilgram iPhone beta acceptance protocol

**Not yet executed.** BUILD-1 validated a simulator IPA only. BUILD-2 device compilation and real iPhone login are separate gates. The user, not GitHub Actions, signs the candidate with their personal certificate using ESign/Feather.

## Artifact validation before handing off

- [ ] Record immutable source SHA, target `debug_arm64` or `release_arm64`, Xcode, Bazel, build run URL and IPA SHA256.
- [ ] Confirm `verify_device_ipa.py` PASS for ARM64 platform **iOS** (not simulator), including the app and every extension.
- [ ] Inspect `CFBundleIdentifier`, display name, `CFBundleURLTypes`, minimum iOS version and all `PlugIns/*.appex` identifiers.
- [ ] Document and remove fake build-time profiles from installed output; users must not rely on self-signed fixtures for actual installation.
- [ ] Ensure a standalone Veilgram icon replaces all official Telegram logos in active icon resources.
- [ ] Avoid making test builds with placeholder API credentials appear functional: `api_id=1`, all-zero hash **cannot log in**.
- [ ] Ensure the installed binary does not leak team IDs, real phone numbers, signing certificates, sessions, developer hostnames or personal values.

## User-side signing (not performed by CI)

1. Download an **actual device** IPA only after the device verification gate passes. Never use BUILD-1's simulator IPA for phone installation.
2. In ESign/Feather choose the user's own certificate and provisioning profile; re-sign the host app **and** all app extensions, with mutually compatible identifiers/entitlements. Do not send signing material to this repository or any issue comment.
3. Capabilities depend on the user's account/profile. Push notifications, associated domains, app groups, Siri, widgets and extension behavior may differ or fail when re-signed. Re-signing cannot grant missing entitlements.
4. Keep app identifiers stable across updates; test clean install first, then update in place. A different ID creates a separate installation and may not migrate local data.
5. Do not post screenshots containing login codes, phone numbers, tokens or personal conversations.

## Manual functional test plan

| Gate | Method | Current state |
|---|---|---|
| Fresh installation | Install user-signed device IPA, ensure launch without crash | NOT TESTED |
| Cold start | Force-close, reboot phone, relaunch | NOT TESTED |
| Login | Verify separate Telegram API app configuration and account login | BLOCKED (fixture credentials) |
| Chat baseline | Send/receive text/media, attach image and file, search, notifications | NOT TESTED |
| Multiple accounts | Switch, log out, ensure isolated local settings | NOT TESTED |
| Veilgram entry | Settings > Veilgram, navigate back, persist UI-only roadmap visibility | NOT TESTED |
| Extensions | Share sheet, widgets, notification service if allowed by signing | NOT TESTED |
| UI | Dark/light, Dynamic Type, VoiceOver and language | NOT TESTED |
| Storage/privacy | No user data in CI or reports, clean removal on logout | NOT TESTED |
| Update | Install next signed build with matching identifier; check no data loss | NOT TESTED |

Do not mark a gate PASS based only on successful compilation, IPA extraction or fake-profile validation. Record reproducible bugs without exposing account data. Never use self-destructing, secret or restricted media as test material for an archive feature.
