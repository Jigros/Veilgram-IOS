# BUILD-2: physical iPhone arm64 (experimental)

**Status: DEVICE COMPILE VERIFIED; REAL INSTALL/LOGIN NOT VERIFIED.**

The earlier BUILD-2 preparation used macOS 26, Xcode 26.2, Bazel 8.4.2 and synthetic compile-only API values. That work has since been superseded by the integrated candidate path.

## Current evidence

- BUILD-12 device-platform ARM64 compile PASS on the current app candidate: run 36798755909.
- BUILD-13 re-audited the assembled icon-pruned candidate IPA: run 36800258357.
- `tools/verify_device_ipa.py` remains the required guard that every checked app/extension executable is ARM64 Mach-O platform **iOS (2)** rather than **iOS Simulator (7)**.
- These passes prove compilation/platform packaging only. They do **not** prove Apple-valid signing, installation on a physical iPhone, Telegram login, push delivery or extension entitlements.

Public Actions must stay fixture-only. Never interpret a synthetic API compilation build as a working Telegram client.

## Private authentication path

A login-capable build uses independently registered Telegram API credentials through the ignored local `.veilgram-private/API_KEYS` file and `tools/prepare_telegram_api_config.py --source external`. The generated build configuration contains the credentials in plain text and must stay private.

Do not put real API credentials, a credential-bearing IPA, Apple certificates, provisioning profiles, private keys, phone numbers, sessions or login codes in Git, GitHub Actions artifacts, PRs, issues or screenshots.

## Device signing boundary

The user signs the private candidate with their own certificate/provisioning profile using ESign/Feather. The resigner must handle the host app and every extension with compatible bundle identifiers and entitlements. Push notifications, associated domains, app groups, Siri, widgets and notification extensions may still fail if the signing profile cannot grant the required capabilities.

## Remaining physical-device gates

1. Build an exact private `debug_arm64` or `release_arm64` IPA on the supported macOS/Xcode toolchain using the external build configuration.
2. Run `verify_device_ipa.py` and the release/branding checks against that exact IPA.
3. Record the source SHA and local IPA SHA256 without publishing the IPA.
4. Re-sign host app plus extensions with the user's own signing assets.
5. Install on a physical iPhone and verify clean launch, login, basic chat/media, account switching and the Veilgram settings/local-feature paths.
6. Test extension/capability behavior separately; do not infer it from compile success.

## Current release blocker

BUILD-13 removed inherited Telegram alternate app icons, but the primary Telegram icon references are still present. Original Veilgram primary artwork must replace them before a release candidate can pass the branding gate.

See `docs/IPHONE_TEST_MATRIX.md` for the device acceptance checklist and `docs/API_IDENTITY.md` for the secret-safe API configuration flow.
