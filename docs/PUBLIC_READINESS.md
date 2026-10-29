# Public repository status — PUBLIC, distribution NOT CLEARED

Checked on 2026-09-30. **Repository visibility was changed to PUBLIC** after a targeted privacy audit; source publication does not establish compliance or signed-build readiness.

## Why public CI is viable

For a public repository, standard GitHub-hosted macOS runners can build public source at no per-minute charge within the GitHub public-runner rules. The build must use the product repository as its only source of truth. The public CI-only helper repo `Jigros/Veilgram-Build` may be retained for independent upstream BUILD-0 but is not needed to fetch private product sources.

The experimental `.github/workflows/build1.yml` on `feature/branding` has a manual trigger, read-only token, no PAT, no Apple signing secrets, synthetic non-login Telegram API fields and no auto-release. Its artifact is an unsigned simulator IPA plus hash/identity evidence. **It has not run and cannot be claimed to work until it is on a default-branch-enabled workflow and successfully executed on macOS.** The existing inherited `.github/workflows/build.yml` must NOT be used for Veilgram: it targets outdated `macos-13`, uses original Telegram names and publishes release artifacts automatically.

## Security/privacy before changing visibility

- [x] Local check on project-authored Git commits outside pinned upstream ancestry: no non-noreply commit author/committer email addresses were observed on 2026-09-30. This checks only commit email fields, not all GitHub account metadata, upstream contributor identities, issue attachments or entire file contents.
- [x] Project-owned commits through the initial import previously underwent an isolated gitleaks audit with zero findings (see PR #17). This does not cover every subsequent change or every inherited upstream file.
- [x] Targeted project-only changed-blob scan: TruffleHog 3.95.3 filesystem mode, 62 Git blob objects not reachable from pinned Telegram upstream, 0 findings, exit 0 (no verification). Separate regex patterns also yielded no likely tokens, keys, local home paths or API hashes; this does NOT imply a clean full inherited history.
- [x] Targeted checks: 37 project-owned commits outside pinned Telegram history; no non-noreply author/committer emails; 18 GitHub issues/PR bodies, 0 issue comments, 0 inline PR comments, 0 repository Actions artifacts, 0 releases, 0 tags, no matching personal path/key patterns. 4 old failed private workflow runs had zero steps in their run jobs. Retain ongoing review for newly published data.
- [ ] Inspect inherited example `*.mobileprovision`, `*.p12`, Watch `Secrets.swift`, and other files: these are upstream sample/fake signing materials; do not classify them as real personal signing keys solely by filename, but independently verify before exposure.
- [ ] Audit submodules and license/attribution per component, not merely top-level LICENSE. Preserve upstream Git history and notices.
- [x] Targeted project Git-object history and GitHub metadata check found no known production API credentials, Apple signing material, sessions or personal paths. This is evidence from the audited objects, not proof that any possible unknown secret never existed.
- [ ] Review workflow behavior for untrusted PRs: do not run user-contributed scripts in a privileged `pull_request_target` job; do not grant write-scoped default token, broad PAT or signing secrets to build jobs. Require approvals for first-time contributors.
- [ ] Decide whether the existing GitHub username `Jigros` being public is acceptable. Noreply commits hide commit email, **not the account identity**, commit timestamps or public activity.
- [ ] Review Telegram API Terms and original client artwork before app distribution; do not confuse GitHub code visibility with Telegram API permissions.

## Decision boundary

Visibility was changed on 2026-09-30 after checks of project-authored history and GitHub metadata, but residual risk remains: a negative secrets scan cannot guarantee absence of personal data. Changing private → public exposes all reachable history and Actions logs, not just the default branch. Rotating secrets and rewriting history require careful planning if a real secret is found. Do not squash upstream history just to conceal author names. GitHub docs: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility and https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository .
