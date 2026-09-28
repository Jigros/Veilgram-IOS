# Verification plan

No feature test has run. BUILD-0 passed for exact upstream in [public run 36378626863](https://github.com/Jigros/Veilgram-Build/actions/runs/36378626863). The earlier private run 36377671456 did not start due GitHub billing. No Veilgram feature test has run.

Anti-delete: receive, sender deletes, local marked copy remains, restart, cache clear, media bytes checked independently, server history unchanged. Edit history: original plus two revisions and restart. Ghost: two accounts; verify read, typing, online and stories from sender side, including reaction/reply server limits, off-state and reconnect. Test groups, channels, bots, secret chats, multi-account and notifications as each hook is implemented. Capture source SHA, toolchain, steps and observed result.
