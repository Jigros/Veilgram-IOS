# BUILD-2: physical iPhone arm64 (experimental)

**Status: PREPARED, NOT BUILT.** BUILD-1 success was for `debug_sim_arm64` only.

Source branch: `feature/build2-device-ipa`; separate manual workflow `.github/workflows/build2.yml` is on `main`. Workflow uses macOS 26, Xcode 26.2, synthetic compile-only `api_id=1` and all-zero `api_hash`, test bundle ID `org.veilgram.buildtwo`; no user signing certificate is needed or requested at this stage.

## Gate

1. GitHub Actions workflow `BUILD-2 Veilgram device arm64 (experimental)` must execute and compile `debug_arm64` successfully.
2. `tools/verify_build1_ipa.py` must validate app/extension bundle identities.
3. `tools/verify_device_ipa.py` must confirm **every checked app/extension executable** has ARM64 Mach-O platform **iOS (2)**, not **iOS Simulator (7)**. This can reject wrong binaries; it cannot guarantee signing/installability.
4. Record actual source SHA, toolchain, simulator/device distinction, exact IPA SHA-256, run URL and artifact retention.
5. Review bundle metadata, entitlements, extension signing and capabilities separately before asking the user to sign locally.

Never interpret a synthetic API compilation build as a working Telegram client. Real login requires independent Telegram API credentials, provisioned without exposing secrets in public Actions, and an actual iPhone smoke test. Keep auth credentials out of the Git repository, workflow logs, public artifacts, and screenshots.

## Device signing boundary

User signs later on iPhone with their own certificate. Veilgram CI must **not** ingest or publish personal Apple .p12 files, provisioning profiles or private keys. A valid resigner must handle the app and every extension, bundle identifiers, entitlements, push notifications and associated capabilities. These outcomes require testing on the device.

## Current blocker

At initial attempt GitHub workflow_dispatch returned HTTP 500, so BUILD-2 has **not** been verified. Static Python syntax and synthetic Mach-O iOS/simulator classification tests passed on NixOS; these are not device build evidence.

## Subsequent project work

After real-device baseline, implement the native Veilgram settings entry with per-account persisted flags and disabled-by-default behavior. Archive/edit-history/media persistence proposals require privacy/compliance assessment before changing TelegramCore behavior. Never claim Ghost Mode, server entitlement spoofing, suppression of official sponsored messages, or self-destruct bypass as supported features.
