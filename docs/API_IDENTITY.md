# Veilgram API identity: local build configuration

Status: **external credential configuration verified; actual Telegram login NOT tested yet**.

This branch adds an AyuGram-style `APP_ID` / `APP_HASH` input adapter for the existing Telegram-iOS build configuration pipeline. It does **not** include, extract, publish or claim authorization to use Telegram's official client credentials, nor does it bypass platform rules. Choosing the credentials is a separate responsibility.

## Verified architecture

- AyuGram Android (`AyuGram/AyuGram4A`, default `rewrite` branch) reads a local `API_KEYS` file in `TMessagesProj/build.gradle` and supplies `APP_ID` / `APP_HASH` through Gradle `BuildConfig`; `BuildVars.java` reads these fields. Its README provides an example. This is a compile-time configuration method, not a dynamically fetched authentication scheme.
- Veilgram upstream already takes `api_id` and `api_hash` in the build JSON: `build-system/Make/BuildConfiguration.py` writes them to Bazel configuration variables. This patch leaves TelegramCore, MTProto, login and sessions untouched.
- `tools/prepare_telegram_api_config.py` adapts the local AyuGram-like file format to the existing JSON schema and never prints credential values.
- `tools/private_device_build.py` wraps the validated BUILD-12 device recipe for private local use. It refuses tracked working-tree changes, keeps credentials/config/artifacts under the ignored `.veilgram-private/` directory, requires macOS for compilation, verifies the generated IPA as iPhone ARM64, and records a local SHA-256 manifest.

## Local-only setup

On the machine that will **compile** iOS (macOS 26 / Xcode 26.2, not NixOS alone):

1. Create the ignored directory `.veilgram-private/` with private permissions.
2. Create `.veilgram-private/API_KEYS` with only these two properties, replacing placeholders with values you are authorized to use:

```properties
APP_ID=REPLACE_WITH_AUTHORIZED_ID
APP_HASH=REPLACE_WITH_AUTHORIZED_32_HEX_HASH
```

3. Run `chmod 600 .veilgram-private/API_KEYS`.
4. Validate the input without compiling:

```sh
python3 tools/private_device_build.py --preflight-only
```

5. On the supported Mac, build the private device IPA:

```sh
python3 tools/private_device_build.py
```

The runner generates `.veilgram-private/veilgram-device-configuration.json`, creates local compile-only provisioning fixtures, performs the `debug_arm64` build, runs the identity/device-platform checks and places the resulting IPA plus reports under `.veilgram-private/artifacts/`. The compile-only signature is **not installable as-is**; re-sign the host app and every extension with the user's own signing assets before installing it on iPhone.

For lower-level/manual use, `tools/prepare_telegram_api_config.py --source external` can still generate the build configuration directly and that configuration can be passed to `build-system/Make/Make.py build`.

The generated JSON is private and contains credentials in plain text with mode `0600`. Never attach it to a public Actions artifact or issue, and never upload the resulting credential-bearing IPA in a public workflow. **API credentials compiled into a distributed client can ultimately be extracted from its binary**; this file-permission guard only prevents accidental repository/workflow exposure.

For compile testing without login, use `--source fixture` in the lower-level configuration adapter and omit `--credentials`. Public BUILD workflows remain fixture-only.

## Current verification state

- External `APP_ID` / `APP_HASH` input: **PASS locally**.
- Credentials/config permissions: **0600 verified**.
- Current credential values present in tracked HEAD files: **0 matches**.
- Private build runner preflight on NixOS: **PASS**.
- BUILD-12 ARM64/iOS candidate compile with fixture API identity: **PASS**.
- Telegram login using the external credentials: **NOT TESTED**.
- ESign/Feather-resigned physical-device installation: **NOT TESTED**.
- Push/associated-domain/app-group/widget/notification-service behavior after re-signing: **NOT TESTED**.

## API terms and project policy

Telegram's API terms require independent registration for third-party clients and may restrict nonconforming clients. The fact that AyuGram says it uses official identifiers is not an authorization for Veilgram, and does not imply safety from account or API enforcement. This branch **implements an input mechanism**, not a preconfigured or approved official identity. Do not misrepresent Veilgram as an official Telegram app.

Sources: [AyuGram4A README](https://github.com/AyuGram/AyuGram4A/blob/rewrite/README.md), [AyuGram4A Gradle file](https://github.com/AyuGram/AyuGram4A/blob/rewrite/TMessagesProj/build.gradle), [AyuGram4A BuildVars.java](https://github.com/AyuGram/AyuGram4A/blob/rewrite/TMessagesProj/src/main/java/org/telegram/messenger/BuildVars.java), [Telegram API terms](https://core.telegram.org/api/terms).
