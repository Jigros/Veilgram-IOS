# Veilgram API identity: local build configuration

Status: **configuration adapter implemented; actual Telegram login NOT tested**.

This branch adds an AyuGram-style `APP_ID` / `APP_HASH` input adapter for the existing Telegram-iOS build configuration pipeline. It does **not** include, extract, publish or claim authorization to use Telegram's official client credentials, nor does it bypass platform rules. Choosing the credentials is a separate responsibility.

## Verified architecture

- AyuGram Android (`AyuGram/AyuGram4A`, default `rewrite` branch) reads a local `API_KEYS` file in `TMessagesProj/build.gradle` and supplies `APP_ID` / `APP_HASH` through Gradle `BuildConfig`; `BuildVars.java` reads these fields. Its README provides an example. This is a compile-time configuration method, not a dynamically fetched authentication scheme.
- Veilgram upstream already takes `api_id` and `api_hash` in the build JSON: `build-system/Make/BuildConfiguration.py` writes them to Bazel configuration variables. This patch leaves TelegramCore, MTProto, login and sessions untouched.
- The added tool `tools/prepare_telegram_api_config.py` adapts the local AyuGram-like file format to the existing JSON schema and never prints credential values.

## Local-only setup

On the machine that will **compile** iOS (macOS 26 / Xcode 26.2, not NixOS alone):

1. Create the ignored directory `.veilgram-private/` with private permissions.
2. Create `.veilgram-private/API_KEYS` with only these two properties, replacing placeholders with values you are authorized to use:

```properties
APP_ID=REPLACE_WITH_AUTHORIZED_ID
APP_HASH=REPLACE_WITH_AUTHORIZED_32_HEX_HASH
```

3. Run `chmod 600 .veilgram-private/API_KEYS`.
4. Generate the build configuration:

```sh
python3 tools/prepare_telegram_api_config.py \
  --source external \
  --credentials .veilgram-private/API_KEYS \
  --output .veilgram-private/veilgram-device-configuration.json \
  --bundle-id org.veilgram.local \
  --team-id AAAAAAAAAA \
  --url-scheme veilgram-local
```

5. Pass `--configurationPath=.veilgram-private/veilgram-device-configuration.json` to `build-system/Make/Make.py build` using an appropriate macOS setup. Device builds still need the BUILD-2 compile-only or genuine provisioning strategy; this adapter does not sign an iPhone IPA.

The generated JSON is also private and contains credentials in plain text with mode `0600`. Never attach it to a public Actions artifact or issue, and never upload the resulting credential-bearing IPA in a public workflow. **API credentials compiled into a distributed client can ultimately be extracted from its binary**; this file-permission guard only prevents accidental *repository and workflow* exposure.

For compile testing without login, use `--source fixture` and omit `--credentials`. Fixture values are an intentionally unusable API ID/hash; BUILD-1, BUILD-2 and BUILD-3 CI remain fixture-only.

## What remains unverified

- Telegram login using externally supplied credentials.
- Server-side acceptance of the selected application identity, device model, platform or app version.
- Compatibility of an app signed later via ESign/Feather.
- Notification service and extension entitlements, associated domains and push delivery.
- AyuGram parity beyond compile-time configuration. AyuGram Android and Desktop clients are not substitutes for end-to-end tests of Telegram-iOS.

## API terms and project policy

Telegram's API terms require independent registration for third-party clients and may restrict nonconforming clients. The fact that AyuGram says it uses official identifiers is not an authorization for Veilgram, and does not imply safety from account or API enforcement. This branch **implements an input mechanism**, not a preconfigured or approved official identity. Do not misrepresent Veilgram as an official Telegram app.

Sources: [AyuGram4A README](https://github.com/AyuGram/AyuGram4A/blob/rewrite/README.md), [AyuGram4A Gradle file](https://github.com/AyuGram/AyuGram4A/blob/rewrite/TMessagesProj/build.gradle), [AyuGram4A BuildVars.java](https://github.com/AyuGram/AyuGram4A/blob/rewrite/TMessagesProj/src/main/java/org/telegram/messenger/BuildVars.java), [Telegram API terms](https://core.telegram.org/api/terms).
