# Telegram API and distribution constraints

Status checked: 2026-09-28. This is an engineering risk record, not legal advice. Re-read the current [Telegram API Terms of Service](https://core.telegram.org/api/terms) before every release because Telegram may update them.

| Area | Current official requirement | Veilgram decision |
|---|---|---|
| API credentials | A third-party client must obtain its own `api_id`. | Use an independent Veilgram application registration. Never reuse official Telegram credentials or commit real credentials. |
| Identity | The app must prominently disclose that it uses the Telegram API; its title must not include “Telegram” unless preceded by “Unofficial”. | Use the independent Veilgram name and an explicit unofficial-client notice. |
| Logo | A third-party app must not use the official Telegram logo. | Create independent icon infrastructure and artwork before distribution. |
| Basic behavior | Basic Telegram functions must work correctly and predictably. | Treat upstream behavior as the baseline and document every intentional difference. |
| Read receipts / Ghost Mode | The terms explicitly prohibit tampering with message read status and name “ghost mode” as an example. | Do not claim or ship Ghost Mode under the official Telegram API without an explicit new product/legal decision. |
| Online / last seen / typing | The terms prohibit preventing these statuses from being displayed or sent correctly. | Do not ship suppression behavior under the current terms. |
| Self-destructing content | The terms prohibit preventing self-destructing content from disappearing. | Do not preserve or bypass self-destructing media/content. |
| Sponsored channel messages | Clients that access channels must support official sponsored messages and may not interfere with them. | Do not remove official sponsored messages. |
| Local archive / Anti-Delete | The named examples do not resolve every ordinary-message archive case; privacy, deletion expectations and platform review remain material risks. | Architecture research may continue, but implementation/distribution requires a separate written scope and compliance decision. Archived records must never masquerade as server state. |

Telegram states that after notice of a breach, failure to fix the highlighted issue within 10 days can lead to API access discontinuation and contact with app stores. That is primarily a Telegram API and distribution risk, not an automatic GitHub repository ban.

GitHub hosting is governed separately by GitHub's Terms and Acceptable Use Policies. Publishing a transparent source fork with preserved notices does not guarantee immunity from complaints or enforcement. Avoid proprietary material, personal data, credentials, deceptive branding, malware, abusive automation and binary dumps in Git history.
