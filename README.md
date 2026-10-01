# Veilgram

Veilgram is a research-stage, unofficial iOS client based on the source of [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS). It is not affiliated with or endorsed by Telegram.

## Current status

- Upstream foundation: Telegram-iOS 12.9.2 at exact commit `6ad963e5b62d354da79040f388ae2b9132fb17b8`, imported with its Git history and submodule references preserved.
- BUILD-0: the unchanged upstream simulator target compiled successfully in public CI ([run 36378626863](https://github.com/Jigros/Veilgram-Build/actions/runs/36378626863)).
- Veilgram runtime integration is active on feature branches, including local archive/edit history, message filters, channel-ad handling and Ghost Mode controls.
- Build, device-test and release readiness are tracked separately from feature implementation.

This repository is the product source of truth. [Veilgram-Build](https://github.com/Jigros/Veilgram-Build) contains CI verification infrastructure only and is not a source mirror.

## Security and credentials

No production Telegram credentials, Telegram sessions, phone numbers, Apple signing assets, certificates, provisioning profiles or private keys belong in Git. Development configuration must remain local and ignored; CI may use synthetic compile-only values. See [SECURITY.md](SECURITY.md).

## Documentation

- [BUILD-0 evidence](docs/BUILD.md)
- [Upstream maintenance strategy](docs/UPSTREAM_STRATEGY.md)
- [Telegram API and distribution constraints](docs/TELEGRAM_API_COMPLIANCE.md)
- [Official upstream build instructions](docs/UPSTREAM_BUILD.md)
- [BUILD-1 branding](docs/BRANDING.md)

Distribution/API considerations are documented separately from engineering capability. They do not act as implementation gates for Veilgram feature development.

Upstream files retain their existing copyright and license notices. No new repository-wide license is asserted by this README.