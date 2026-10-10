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
    "group-action-boundary",
    "messages.count <= 10" in source
    and "Set(messageNode.messages().map { $0.id }) == Set(messages.map { $0.id })" in source
    and "!chatPresentationInterfaceState.myCopyProtectionEnabled" in source,
    "Group Message Shot must only be offered when the visible node contains the whole bounded group.",
)
require(
    "live-node-boundary",
    "nodeMessages.count == requestedIds.count" in source
    and "Set(nodeMessages.map { $0.id }) == requestedIds" in source
    and "nodeMessages.allSatisfy({ currentMessage in" in source
    and "!currentMessage.containsSecretMedia" in source
    and "currentMessage.activeEphemeralReplacementMessage == nil" in source
    and "currentMessage.effectiveMedia.contains(where: { $0 is TelegramMediaExpiredContent })" in source,
    "All captured node messages must match the requested IDs and remain unprotected and unexpired.",
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
