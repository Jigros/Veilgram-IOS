# Verified integration gate: run 90

Source: `75237a77d608174a600201271864f660a3b1e0d7`.
Upstream base: Telegram-iOS 12.9.2, `6ad963e5b62d354da79040f388ae2b9132fb17b8`.
Environment: GitHub Actions `macos-26`, pinned Xcode 26.2, Bazel 8.4.2; synthetic compile-only API configuration.

[Run #90](https://github.com/Jigros/Veilgram-IOS/actions/runs/37020223654): `swift-tests` job 110881257257 SUCCESS; `ios-build` job 110881668594 SUCCESS, including Compile iOS simulator.

Compile command (workflow archive-runtime-reliability.yml):

```sh
python3 -u build-system/Make/Make.py --cacheDir="$RUNNER_TEMP/veilgram-bazel-cache" build --configurationPath=archive-runtime-configuration.json --xcodeManagedCodesigning --configuration=debug_sim_arm64 --buildNumber=1
```

Diagnostic artifact: `archive-runtime-reliability-diagnostics`, id `11234744864`, 67957 bytes. GitHub artifact SHA-256: `1d07b2bf01a2c4f34166178e717d103e7f9dca00ee0974b2e6a0b32cefc3778e`.

This proves compilation for the exact source above. Later Ghost direct/bulk-receipt patches require a new run. This is not physical-device acceptance, signed-install evidence or proof of network privacy on a real account.
