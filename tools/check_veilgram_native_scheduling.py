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
send_now = chat[chat.index("sendScheduledMessagesNow: {"):chat.index("editScheduledMessagesTime: {", chat.index("sendScheduledMessagesNow: {"))]
assert "for messageId in messageIds where sentMessageIds.insert(messageId).inserted" in send_now
assert "sendScheduledMessageNowInteractively(messageId: messageId)" in send_now
assert "messageIds.first!" not in send_now
context_menu = (root / "submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift").read_text()
assert "data.messageActions.options.contains(.editScheduledTime) && (!selectAll || messages.count == 1)" in context_menu
group_menu = chat[chat.index("strongSelf.presentationData.strings.ScheduledMessages_SendNow"):chat.index("strongSelf.presentationData.strings.Conversation_ContextMenuDelete", chat.index("strongSelf.presentationData.strings.ScheduledMessages_SendNow"))]
assert "if messages.count == 1 {" in group_menu
assert group_menu.index("if messages.count == 1 {") < group_menu.index("editScheduledMessagesTime(messages.map { $0.id })")
print("PASS: native schedule routing, real Premium repeat boundary, group send-now and single-message edit")
