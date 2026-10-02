#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
item = (ROOT / "submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageItemImpl.swift").read_text(encoding="utf-8")
view = (ROOT / "submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift").read_text(encoding="utf-8")

checks = []

def require(name, condition, detail):
    checks.append((name, condition, detail))

merge_start = item.find("public func mergedWithItems")
merge_end = item.find("public func updateNode", merge_start)
merge_body = item[merge_start:merge_end] if merge_start >= 0 and merge_end > merge_start else ""

require(
    "grouping-identity-unchanged",
    "veilgramRenderDecision" not in merge_body
    and "messagesShouldBeMerged" in merge_body,
    "Ad collapse must not alter Telegram's message grouping/merge identity.",
)
require(
    "collapsed-layout-only",
    item.count("height: 42.0") >= 2
    and "effectiveLayout" in item
    and "node.contentSize = effectiveLayout.contentSize" in item,
    "Collapse should be represented as a bounded layout change, not message replacement/removal.",
)
require(
    "reveal-targeted-refresh",
    "VeilgramMessageRenderRuntime.reveal" in view
    and "requestMessageUpdate(item.message.id" in view,
    "Reveal must refresh only the selected message row.",
)
require(
    "reuse-state-reset",
    "veilgramCollapseButtonNode?.removeFromSupernode()" in view
    and "veilgramCollapseButtonNode = nil" in view,
    "Reused chat nodes must clear collapse controls to avoid scroll/reuse leakage.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} ad grouping/scroll/reveal source checks")
