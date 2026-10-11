#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")

checks = []

def require(name, condition, detail):
    checks.append((name, condition, detail))

require(
    "message-shot-safely-disabled",
    'text: "Message Shot"' not in source,
    "Message Shot remains removed from the menu until the user-reported crash has a verified fix.",
)
require(
    "send-logs-not-offered",
    'text: "Send Logs"' not in source,
    "The per-media debug-log action must not appear in message context menus.",
)
require(
    "foundation-version",
    "Telegram-iOS 13.0 foundation" in settings
    and "12.9.2 foundation" not in settings,
    "Veilgram settings must report the imported Telegram foundation version.",
)
require(
    "archive-shortcut-routing",
    "VeilgramLocalArchiveDetailController(context: self.accountContext, mode: mode)" in settings,
    "Message/edit/media shortcuts must open their distinct archive detail modes directly.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} Message Shot source checks")
