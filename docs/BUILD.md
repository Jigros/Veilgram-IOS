# Build status

## Telegram 13.0 upstream BUILD-0 — PASS

The official Telegram-iOS source at `f1dd7a2dbd02cbbf513e75d5695d8d36d1cf5838` compiled as a simulator target on `macos-26` with Xcode 26.6 and Bazel 9.2.0. The CI-only configuration and simulator provisioning override are recorded in the evidence; this does not prove a signed build, simulator launch or device behavior.

- CI repository SHA: `812cd9cfe1ceffe3f9648abc6d3ea7cff31c2659`; [run 38038740372](https://github.com/Jigros/Veilgram-Build/actions/runs/38038740372), [build0 job](https://github.com/Jigros/Veilgram-Build/actions/runs/38038740372/job/114174574204).
- [Evidence artifact 11665654313](https://github.com/Jigros/Veilgram-Build/actions/runs/38038740372/artifacts/11665654313); uploaded ZIP SHA256 `97eabae044c187dd999123b963b6476f03a4e7a59dcb10fa92d2003289f06452`.
- Recorded exit code `0`; Bazel reported `Build completed successfully, 7712 total actions`.
- `build0-simulator.ipa` SHA256 `4b450d2729780b5fc5fa07bf3b34e3e74845948bdd7f3f0a5c29f8d64ebd79dd`; `build0.log` SHA256 `bfe5c7045b95bbb001a332d03cc3de585202baac5a3959173f67135a0d1b3aa4`.
- Veilgram 13.0 candidate `f42e07291206a55f387b11b9f9ce20d885ef8bb4` independently passed [source tests and full simulator compile](https://github.com/Jigros/Veilgram-IOS/actions/runs/38042658752). Runtime and physical-device acceptance remain open.

## Telegram 12.9.2 upstream BUILD-0 — PASS

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

The ZIP was downloaded from the GitHub workflow artifact, and both SHA256 values were independently recomputed from its contained IPA and log; both match the included manifests. The IPA is an **unsigned simulator build of unchanged upstream** (not an installable/signed Veilgram iPhone build). Neither release signing nor Veilgram BUILD-1 is validated by BUILD-0 evidence alone. See independent BUILD-1 evidence below.

Private run [36377671456](https://github.com/Jigros/Veilgram-IOS/actions/runs/36377671456) executed no build step because of a GitHub Actions account billing/spending restriction. It is not a Telegram source compilation failure.

## BUILD-1 — PASS (branded iOS simulator, not signed-device IPA)

- Run: [36707107223](https://github.com/Jigros/Veilgram-IOS/actions/runs/36707107223)
- Job: `build1`, conclusion **success**. Actual `Compile branded simulator` step **success**, compile exit **0**.
- Workflow main commit: `9355dad319dc931ee9160a7e4c025de9fbb232b9`.
- **Actual branded source checkout** in the job: `a30ea65c53019f22098405fa2b90c179964e2a72` on `feature/branding`. This is NOT the same SHA as the workflow-trigger main commit. Future builds should pin or display both.
- Upstream foundation: Telegram-iOS `6ad963e5b62d354da79040f388ae2b9132fb17b8`.
- Toolchain: GitHub-hosted `macos-26`, Xcode **26.2**; the workflow checked the versions.json requirement for Bazel **8.4.2**. This does not independently prove that exact runtime Bazel binary without a separate version capture.
- Configuration: `debug_sim_arm64`; synthetic `api_id` / `api_hash`, bundle ID `org.veilgram.buildone`, no personal Apple signing materials.
- Verification: `tools/check_veilgram_branding.py` PASS (19 locales). Offline IPA identity checker PASS, no reported problems, app name `Veilgram`, expected bundle ID and six matching extension identifiers.
- **Simulator IPA SHA256** as printed by the completed job's verifier: `0c8450c0a41c4d159ae92b4564cff1d766ef3de973b706a43f730566474c1f03`.
- Saved artifact: [build1-simulator-evidence #11094616666](https://github.com/Jigros/Veilgram-IOS/actions/runs/36707107223/artifacts/11094616666) (GitHub retention 7 days, expiration **2026-10-07**). Artifact ZIP digest as reported by GitHub: `sha256:ed4d0305a83b94261935aa6d8b004dbcbc251f9c792aefc8cfcc76b91433d361`. On NixOS, the stored artifact was downloaded independently via GitHub CLI, extracted, and SHA-256 was recomputed locally from the **548,618,982-byte IPA**. The digest exactly matched both the CI verifier and its artifact manifest. Running `tools/verify_build1_ipa.py` again on this downloaded IPA returned PASS: 19 localizations, six extensions, zero identity problems. ZIP inspection found 12 code-signature-related entries and no standalone `.xcent` members; this does NOT certify Apple signing, entitlements validity or real-device installability.
- First run #36706226051 failed before compilation due to the standalone repository's incorrect resolution of relative upstream submodule URLs. The successful run used official TelegramMessenger upstream submodule URLs while preserving Git SHA references.

**Not established by BUILD-1:** signed iPhone IPA, actual simulator startup/URL handling, runtime functionality, original icon/branding compliance, push notifications, production Telegram API login, or file-level distribution license clearance. Keep PRs #17/#18 in draft until review gates are satisfied.

