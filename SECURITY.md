# Security policy

Veilgram has no released or supported product version yet. Security reports can still concern source, build infrastructure or accidental disclosure.

## Reporting

Use GitHub's private **Report a vulnerability** flow in the repository Security tab. Do not place credentials, session material, phone numbers, signing assets or exploit details in a public issue or pull request. If private reporting is unavailable, create only a minimal public issue asking the owner to enable a private channel; include no sensitive payload.

## Data that must never be committed

- Telegram `api_id` / `api_hash` used by a real application;
- Telegram session databases, auth keys, exported chats or phone numbers;
- Apple certificates, private keys, `.p12` / `.pfx` files or provisioning profiles;
- passwords, access tokens, deploy keys or signing secrets;
- local absolute paths, machine-specific configuration or user datasets.

Keep local development configuration under the ignored `.veilgram-private/` directory. Start from the official minimal development configuration template and use synthetic values only for compile-only CI.

## Publication gate

Before making the repository public or publishing an artifact:

1. scan all project-authored branches and history for secrets;
2. inspect commit author/committer identities and repository discussions for personal data;
3. review inherited upstream findings separately from Veilgram-owned changes;
4. confirm licenses, notices, trademarks and submodule references are preserved;
5. enable GitHub secret scanning and push protection where available;
6. verify that no Actions artifact or release contains credentials, sessions or signing material.

If a secret is found, revoke or rotate it first. Removing it from the latest tree alone is not sufficient because Git history may retain it.
