#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift").read_text(encoding="utf-8")

checks = []

def require(name, condition, detail):
    checks.append((name, condition, detail))

require(
    "context-action",
    'text: "Message Shot"' in source,
    "Message Shot must be exposed from the message context menu.",
)
require(
    "copy-protection-boundary",
    "if !isCopyProtected {" in source
    and source.find('text: "Message Shot"') > source.find("if !isCopyProtected {"),
    "Message Shot must stay inside the existing non-copy-protected branch.",
)
require(
    "local-render",
    "UIGraphicsImageRenderer" in source
    and "drawHierarchy" in source
    and "messageNode.view" in source,
    "Message Shot must render locally from the selected message node.",
)
require(
    "system-share",
    "UIActivityViewController" in source
    and "activityItems: [image]" in source,
    "Generated image must be handed to the system share sheet.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} Message Shot source checks")
