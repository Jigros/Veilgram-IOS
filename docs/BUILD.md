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

The first evidence upload retained the full log and metadata but not the produced simulator IPA. **The subsequent simulator artifact retention run also passed**:

- Follow-up run: [36382324066](https://github.com/Jigros/Veilgram-Build/actions/runs/36382324066)
- Build-infrastructure commit: `fb43be5386be264d82d52675725054812d76b0ac`
- Artifact: [build0-evidence (ID 10954148132)](https://github.com/Jigros/Veilgram-Build/actions/runs/36382324066/artifacts/10954148132)
- Uploaded evidence ZIP digest: `sha256:2601b417e6f7d8367cc204ab077f0eadfae4321a2be828965ae87af464054f39`
- `build0-simulator.ipa` SHA256: `e722636da4bf24b3f0f521fd82eb815643035cd2e6554d4ad36ab8a5a023dc77`
- `build0.log` SHA256: `19e757d6c10d26f54c249f2cf2faa7a07358bcfbd54c37b7a8ecf1a9c5a49aca`
- Result: `build0-exit-code.txt` = `0`; `5886` Bazel actions; `Telegram/Telegram` / `debug_sim_arm64`.

The ZIP was downloaded from the GitHub workflow artifact, and both SHA256 values were independently recomputed from its contained IPA and log; both match the included manifests. The IPA is an **unsigned simulator build of unchanged upstream** (not an installable/signed Veilgram iPhone build). Neither release signing, private source checkout nor BUILD-1 is validated by this evidence.

Private run [36377671456](https://github.com/Jigros/Veilgram-IOS/actions/runs/36377671456) executed no build step because of a GitHub Actions account billing/spending restriction. It is not a Telegram source compilation failure.

## BUILD-1 — NOT STARTED

BUILD-1 will validate branding-only Veilgram changes after the upstream foundation is reviewed. No Veilgram product compilation has passed yet.
