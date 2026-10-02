#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

prefs = (ROOT / "submodules/VeilgramLocalFeatures/Sources/VeilgramSendConfirmationPreferences.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")
chat = (ROOT / "submodules/TelegramUI/Sources/ChatController.swift").read_text(encoding="utf-8")

checks = []

def require(name, condition, detail):
    checks.append((name, condition, detail))

require(
    "per-account-pref",
    "accountPeerId" in prefs and "veilgram.sendConfirmation.v1." in prefs,
    "Send confirmation preference must be per-account.",
)
require(
    "settings-toggle",
    "Confirm before sending" in settings
    and "sendConfirmationChanged" in settings,
    "Veilgram settings must expose the send confirmation toggle.",
)
require(
    "user-send-only",
    "sendCurrentMessage: { [weak self] silentPosting, messageEffect in" in chat
    and "VeilgramSendConfirmationPreferences.isEnabled" in chat
    and "let performSend: (Int?) -> Void" in chat,
    "Confirmation must wrap the user-initiated current-message send entry point.",
)
require(
    "confirmation-before-enqueue",
    "let performSend: (Int?) -> Void" in chat
    and "VeilgramSendConfirmationPreferences.isEnabled" in chat
    and 'title: "Send"' in chat
    and "action: sendNow" in chat
    and "} else {\n                sendNow()\n            }" in chat,
    "The enqueue closure must only be invoked by confirm or the disabled-preference fast path.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} send-confirmation source checks")
