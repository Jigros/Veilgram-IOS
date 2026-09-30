# Public repository readiness — NOT CLEARED

Checked on 2026-09-30. **Repository is still private; this is a publication gate, not permission to publish automatically.**

## Why public CI is viable

For a public repository, standard GitHub-hosted macOS runners can build public source at no per-minute charge within the GitHub public-runner rules. The build must use the product repository as its only source of truth. The public CI-only helper repo `Jigros/Veilgram-Build` may be retained for independent upstream BUILD-0 but is not needed to fetch private product sources.

The experimental `.github/workflows/build1.yml` on `feature/branding` has a manual trigger, read-only token, no PAT, no Apple signing secrets, synthetic non-login Telegram API fields and no auto-release. Its artifact is an unsigned simulator IPA plus hash/identity evidence. **It has not run and cannot be claimed to work until it is on a default-branch-enabled workflow and successfully executed on macOS.** The existing inherited `.github/workflows/build.yml` must NOT be used for Veilgram: it targets outdated `macos-13`, uses original Telegram names and publishes release artifacts automatically.

## Security/privacy before changing visibility

- [x] Local check on project-authored Git commits outside pinned upstream ancestry: no non-noreply commit author/committer email addresses were observed on 2026-09-30. This checks only commit email fields, not all GitHub account metadata, upstream contributor identities, issue attachments or entire file contents.
- [x] Project-owned commits through the initial import previously underwent an isolated gitleaks audit with zero findings (see PR #17). This does not cover every subsequent change or every inherited upstream file.
- [ ] Run updated whole-repository and project-only secret scanning with current gitleaks/trufflehog and manual review; separate known upstream public test vectors from Veilgram-specific findings.
- [ ] Review all Git history, filenames, issue/PR descriptions/comments, review bodies, tags, Actions **history/logs/artifacts**, Releases and user-owned file metadata for emails, real names, hostnames, home directories, device IDs, IPs, auth values or private file paths.
- [ ] Inspect inherited example `*.mobileprovision`, `*.p12`, Watch `Secrets.swift`, and other files: these are upstream sample/fake signing materials; do not classify them as real personal signing keys solely by filename, but independently verify before exposure.
- [ ] Audit submodules and license/attribution per component, not merely top-level LICENSE. Preserve upstream Git history and notices.
- [ ] Confirm `.veilgram-private/`, production API credentials, Apple certificates/profiles, sessions, phone numbers, crash dumps, build directories and user data have **never** entered project-owned commits, branches, Actions artifacts or issues.
- [ ] Review workflow behavior for untrusted PRs: do not run user-contributed scripts in a privileged `pull_request_target` job; do not grant write-scoped default token, broad PAT or signing secrets to build jobs. Require approvals for first-time contributors.
- [ ] Decide whether the existing GitHub username `Jigros` being public is acceptable. Noreply commits hide commit email, **not the account identity**, commit timestamps or public activity.
- [ ] Review Telegram API Terms and original client artwork before app distribution; do not confuse GitHub code visibility with Telegram API permissions.

## Decision boundary

Only change repository visibility after the full checklist is reviewed; a single negative gitleaks result cannot prove absence of personal data. Changing private → public exposes all reachable history and Actions logs, not just the default branch. Rotating secrets and rewriting history require careful planning if a real secret is found. Do not squash upstream history just to conceal author names. GitHub docs: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility and https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository .
