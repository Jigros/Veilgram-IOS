# Build status

## BUILD-0 — PASS

BUILD-0 compiled the unchanged official Telegram-iOS simulator target from exact upstream commit `6ad963e5b62d354da79040f388ae2b9132fb17b8`.

- Repository: [Jigros/Veilgram-Build](https://github.com/Jigros/Veilgram-Build)
- Successful run: [36378626863](https://github.com/Jigros/Veilgram-Build/actions/runs/36378626863)
- Target: `//Telegram:Telegram`
- Configuration: `debug_sim_arm64`
- Result: exit code 0; Bazel reported `Build completed successfully, 5886 total actions`
- Runner: standard `macos-26`
- macOS: 26.6.2
- Xcode: 26.2 (17C52)
- Swift: 6.2.3
- Bazel: 8.4.2
- Build repository commit: `838cf0d80016c35193e3836a917546e5d5fde56a`
- Evidence artifact ID: `10952977163`
- Evidence ZIP digest: `sha256:ed45dc9a381a6f1ec101cbec849013fea98da17b443a7f964149f6a22d30a7f3`
- `build0.log` SHA256: `cec14590f5898b0a9071324767407c714d6628d362db7795ebacebd47c957cfd`

The first evidence upload retained the full log and metadata but not the produced simulator IPA. Follow-up [run 36382324066](https://github.com/Jigros/Veilgram-Build/actions/runs/36382324066), at build-infrastructure commit `fb43be5386be264d82d52675725054812d76b0ac`, reruns the same real compilation and is intended to retain and hash the IPA. Do not invent an IPA hash before that run completes.

Private run [36377671456](https://github.com/Jigros/Veilgram-IOS/actions/runs/36377671456) executed no build step because of a GitHub Actions account billing/spending restriction. It is not a Telegram source compilation failure.

## BUILD-1 — NOT STARTED

BUILD-1 will validate branding-only Veilgram changes after the upstream foundation is reviewed. No Veilgram product compilation has passed yet.
