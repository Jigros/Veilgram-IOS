#!/usr/bin/env python3
from pathlib import Path

path = Path("submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift")
text = path.read_text(encoding="utf-8")
start = text.index("@objc private func rankButtonPressed()")
end = text.index("private var playedSwipeToReplyHaptic", start)
handler = text[start:end]

assert "veilgramLikelyChannelAd" in handler
assert "displayMessageTooltip" in handler
assert "The message is not hidden." in handler
veilgram_block = handler[:handler.index("guard let peer")]
assert "openRankInfo" not in veilgram_block
print("PASS: Possible ad badge uses Veilgram tooltip and cannot fall through to Telegram rank info")
