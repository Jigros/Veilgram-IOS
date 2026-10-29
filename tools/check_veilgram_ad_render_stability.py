#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
item = (ROOT / "submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageItemImpl.swift").read_text(encoding="utf-8")
view = (ROOT / "submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")
render_runtime = (ROOT / "submodules/VeilgramLocalFeatures/Sources/VeilgramMessageRenderRuntime.swift").read_text(encoding="utf-8")
node = (ROOT / "submodules/TelegramUI/Sources/ChatControllerNode.swift").read_text(encoding="utf-8")
menu = (ROOT / "submodules/TelegramUI/Sources/Chat/ChatControllerOpenMessageContextMenu.swift").read_text(encoding="utf-8")
history = (ROOT / "submodules/TelegramUI/Sources/ChatHistoryEntriesForView.swift").read_text(encoding="utf-8")
history_node = (ROOT / "submodules/TelegramUI/Sources/ChatHistoryListNode.swift").read_text(encoding="utf-8")
classifier = (ROOT / "submodules/TelegramUI/Sources/VeilgramChannelAdClassifier.swift").read_text(encoding="utf-8")

checks = []

def require(name, condition, detail):
    checks.append((name, condition, detail))

merge_start = item.find("public func merged(with neighbors:")
merge_end = item.find("public func updateNode", merge_start)
merge_body = item[merge_start:merge_end] if merge_start >= 0 and merge_end > merge_start else ""

require(
    "grouping-identity-unchanged",
    "veilgramRenderDecision" not in merge_body
    and "chatMessageMerge(upper:" in merge_body,
    "Ad collapse must not alter Telegram's message grouping/merge identity.",
)
require(
    "sponsored-surfaces-hidden",
    'showSponsoredPreferenceKey = "veilgram.settings.v1.\\(self.context.account.id.int64).showSponsoredMessages"' in node
    and "if !hideTopPanels, showSponsoredMessages, let _ = self.chatPresentationInterfaceState.adMessage" in node
    and 'if message.adAttribute != nil && !UserDefaults.standard.bool(forKey: "veilgram.settings.v1.\\(context.account.id.int64).showSponsoredMessages")' in history
    and "let shouldShowSponsoredMessages = UserDefaults.standard.object(forKey: showSponsoredPreferenceKey) == nil" in history_node
    and "self.allAdMessages = (shouldShowSponsoredMessages ? fixedMessage : nil, [], 0)" in history_node
    and "if !veilgramAdOptions.enabled && view.laterId == nil && !view.isLoading" in history
    and "disableScreenshots: isSecret" in menu
    and "signals.contains(\"disclosure\")" in classifier
    and "signals.contains(\"erid\")" in classifier
    and "collapseThreshold" in classifier,
    "Opt-in sponsored hiding must leave Telegram copy protection enabled for protected chats.",
)
require(
    "sponsored-preference-default-and-change",
    "showSponsoredPreferenceKey" in settings
    and "object(forKey: self.showSponsoredPreferenceKey) == nil ? true" in settings
    and 'Notification.Name("org.veilgram.ads.show-sponsored-changed")' in settings
    and "shouldShowSponsoredMessages" in history_node,
    "Sponsored surfaces must remain visible by default and use an account-scoped live setting.",
)
require(
    "heuristic-badge-boundary",
    "isOfficialSponsoredMessage: message.adAttribute != nil" in history
    and "let veilgramLikelyChannelAd = message.adAttribute == nil && veilgramDecision.action != .keep" in history
    and "if isOfficialSponsored {\n            let key" in render_runtime
    and "isAdvertisement: true" in render_runtime
    and "precondition(decision?.isAdvertisement == true)" in (ROOT / "tools/test_veilgram_channel_ad_classifier.swift").read_text(encoding="utf-8")
    and "showSponsoredMessages" in render_runtime,
    "Official sponsored messages remain Telegram-typed and collapse only through the explicit local hide setting.",
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
