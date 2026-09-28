# Build status

BUILD-0: **NOT RUN**. No iOS artifact exists.

At the candidate official upstream SHA, [versions.json](https://github.com/TelegramMessenger/Telegram-iOS/blob/6ad963e5b62d354da79040f388ae2b9132fb17b8/versions.json) specifies Telegram 12.9.2, Xcode 26.2, deployment Xcode 26.2, Bazel 8.4.2 with checksum `45e9388abf21d1107e146ea366ad080eb93cb6a5f3a4a3b048f78de0bc3faffa`, and macOS 26. Re-read this file at every build SHA. Swift version is not separately specified there; derive it from the actual Xcode installation.

NixOS is for source inspection, scripts and checks. Real simulator/device compilation needs compatible macOS/Xcode. No hosted macOS runner availability has been validated. Do not add an Actions workflow with an invented runner/Xcode combination. First verify available runner image and Xcode 26.2, then pin them in CI and log commit, upstream, config, tools, signing, target, logs and artifact SHA256. Do not claim success for project generation or Linux checks.

The official [README](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/README.md) documents `build-system/Make/Make.py` and `--disableProvisioningProfiles` for simulator project generation. App API credentials and signing materials must remain outside git.
