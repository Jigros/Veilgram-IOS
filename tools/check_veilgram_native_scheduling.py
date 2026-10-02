#!/usr/bin/env python3
from pathlib import Path
root = Path(__file__).resolve().parents[1]
chat = (root / "submodules/TelegramUI/Sources/ChatController.swift").read_text()
picker = (root / "submodules/TelegramUI/Components/ChatScheduleTimeController/Sources/ChatScheduleTimeScreen.swift").read_text()
settings = (root / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text()
assert "VeilgramDelayedSendPreferences" not in chat + settings
assert not (root / "submodules/VeilgramLocalFeatures/Sources/VeilgramDelayedSendPreferences.swift").exists()
assert "scheduleCurrentMessage: {" in chat
assert "scheduleTime: result.time, repeatPeriod: result.repeatPeriod" in chat
assert "ChatScheduleTimeScreen(" in chat
assert "isLocked: !component.context.isPremium" in picker
assert "if component.context.isPremium {" in picker
assert "isPremiumPresentation" not in picker
assert "requestEditMessage" in chat and "scheduleRepeatPeriod" in chat
print("PASS: native schedule routing, real Premium repeat boundary, no custom delay modal")
