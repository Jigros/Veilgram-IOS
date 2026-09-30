# BUILD-2: physical iPhone arm64 (experimental)

**Status: BUILD-2 COMPILE + IPA VERIFIER PASS** in [run 36714922763](https://github.com/Jigros/Veilgram-IOS/actions/runs/36714922763). This establishes a device-platform IPA artifact from fixture inputs, **NOT** installability, Apple-valid signing, Telegram login or runtime behavior. BUILD-1 was simulator-only.

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

Manual GitHub workflow_dispatch returned HTTP 500 initially. The bounded `push` trigger started [run 36713904845](https://github.com/Jigros/Veilgram-IOS/actions/runs/36713904845), which failed at **Bazel analysis** of `WidgetExtension`: device builds require provisioning profiles even if regular signing is disabled. This was NOT an Objective-C/Swift compilation failure.

Fix under evaluation: generate nine **compile-only CMS profiles** from already-public self-signed upstream testing material, rewritten to `org.veilgram.buildtwo`. The generated fixtures are NOT valid Apple provisioning, are NOT for installation and are never real developer credentials. The generator passed a local NixOS CMS parse/identity verification test. The corrected run [36714922763](https://github.com/Jigros/Veilgram-IOS/actions/runs/36714922763) subsequently **PASSED** all steps: device arm64 compile, identity checker, Mach-O iOS platform checker, validated IPA artifact upload and diagnostics. Build-time self-signed fixture materials are not installable Apple provisioning; user-side signing, app extensions and login are separate gates. Do not claim that fixture API ID/hash can authenticate Telegram. Artifact hash has not yet been independently recomputed after download in this documentation.

Device IPA validator now has six passing synthetic unit tests (device/simulator, app/extension ID, corrupted IPA), but an actual iPhone Mach-O IPA is still pending.

## Subsequent project work

After real-device baseline, implement the native Veilgram settings entry with per-account persisted flags and disabled-by-default behavior. Archive/edit-history/media persistence proposals require privacy/compliance assessment before changing TelegramCore behavior. Never claim Ghost Mode, server entitlement spoofing, suppression of official sponsored messages, or self-destruct bypass as supported features.
