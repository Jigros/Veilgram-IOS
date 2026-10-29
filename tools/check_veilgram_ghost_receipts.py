from pathlib import Path
root = Path(__file__).resolve().parents[1]
manager = (root / "submodules/TelegramCore/Sources/State/ManagedSynchronizeConsumeMessageContentsOperations.swift").read_text()
history = (root / "submodules/TelegramUI/Sources/ChatHistoryListNode.swift").read_text()
send = (root / "submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift").read_text()
assert "operation.messageIds.filter" in manager
assert "AutoremoveTimeoutMessageAttribute" in manager and "AutoclearTimeoutMessageAttribute" in manager
assert "guard !messageIds.isEmpty" in manager
assert manager.count("id: messageIds.map") == 2
assert "id: operation.messageIds.map" not in manager
read = history[history.index("self.readHistoryDisposable.set"):history.index("self.canReadHistoryDisposable?.dispose()", history.index("self.readHistoryDisposable.set"))]
assert read.index("readOnInteractionOnly") < read.index("previousMaxIncomingMessageIndexByNamespace.modify")
assert "readVisibleMessagesOnSendInteraction()" in send
assert "!shouldDivert && scheduleTime == nil && messageIds.contains" in send
controller = (root / "submodules/TelegramUI/Sources/ChatController.swift").read_text()
generic_send = controller[controller.index("func sendMessages(_ messages: [EnqueueMessage]"):controller.index("func enqueueMediaMessages(", controller.index("func sendMessages(_ messages: [EnqueueMessage]"))]
assert "if isImmediateInteraction && messageIds.contains(where: { $0 != nil })" in generic_send
interaction = history[history.index("func readVisibleMessagesOnSendInteraction()"):history.index("public func disconnect()", history.index("func readVisibleMessagesOnSendInteraction()"))]
callback = interaction[interaction.index("startStandalone(next:"):]
assert callback.index("self.canReadHistoryValue") < callback.index("self.context.applyMaxReadIndex")
assert callback.index("VeilgramGhostModeRuntimePreferences.readOnInteractionOnly") < callback.index("self.context.applyMaxReadIndex")
assert callback.index("!VeilgramGhostModeRuntimePreferences.suppressReadReceipts") < callback.index("self.context.applyMaxReadIndex")
receipt_tests = (root / "tools/test_veilgram_ghost_receipts.swift").read_text()
assert "let mixedReceipts = [" in receipt_tests
assert "retainedReceipts.map(\\.id) == [2, 3]" in receipt_tests
assert "requiresProtocolReceipt: $0.requiresProtocol" in receipt_tests
print("PASS: receipt queue filtering and automatic/immediate-send read paths")
thread = (root / "submodules/TelegramCore/Sources/TelegramEngine/Messages/ReplyThreadHistory.swift").read_text()
apply = thread[thread.index("func applyMaxReadIndex(messageIndex:"):thread.index("public class ReplyThreadHistoryContext")]
assert apply.index("VeilgramGhostModeRuntimePreferences.suppressReadReceipts") < apply.index("Api.functions.messages.readSavedHistory")
assert apply.index("VeilgramGhostModeRuntimePreferences.suppressReadReceipts") < apply.index("Api.functions.messages.readDiscussion")
assert "&& !suppressAutomaticRead" in history
print("PASS: thread read RPC boundary and read-on-interaction arrival/reaction listeners")

personal = (root / "submodules/TelegramCore/Sources/State/ManagedConsumePersonalMessagesActions.swift").read_text()
for name in ["synchronizeConsumeMessageContents", "synchronizeReadMessageReactionsOrPollVotes"]:
    body = personal[personal.index("private func " + name + "("):]
    assert body.index("suppressGhostPersonalRead") < body.index("network.request")
assert "consumed: true, pending: false" in personal
assert "action: nil" in personal and "tags.remove(.unseenReaction)" in personal
forum = (root / "submodules/TelegramCore/Sources/TelegramEngine/Messages/ApplyMaxReadIndexInteractively.swift").read_text()
assert forum.count("if !viewTracker.veilgramSuppressReadReceipts {") == 6
tracker = (root / "submodules/TelegramCore/Sources/State/AccountViewTracker.swift").read_text()
live = tracker[tracker.index("public func updateSeenLiveLocationForMessageIds"):]
assert live.index("if self.veilgramSuppressReadReceipts") < live.index("readMessageContents")
bulk = (root / "submodules/TelegramCore/Sources/State/ManagedSynchronizeMarkAllUnseenPersonalMessagesOperations.swift").read_text()
for name in ["synchronizeMarkAllUnseen", "synchronizeMarkAllUnseenReactions", "synchronizeMarkAllUnseenPollVotes"]:
    body = bulk[bulk.index("private func " + name + "("):]
    assert body.index("suppressReadReceipts") < body.index("network.request")
all_chats = (root / "submodules/TelegramCore/Sources/TelegramEngine/Messages/MarkAllChatsAsRead.swift").read_text()
assert all_chats.index("suppressReadReceipts") < all_chats.index("channels.readHistory")
print("PASS: mention/reaction completion, six forum RPCs, live-location and bulk read boundaries")
assert bulk.count("let signal: Signal<Void, Bool> = deferred") == 2
print("PASS: bulk reaction/poll retry subscriptions recheck live Ghost state")

recording = (root / "submodules/TelegramUI/Sources/Chat/ChatControllerMediaRecording.swift").read_text()
audio_send = recording[recording.index("func sendMediaRecording("):recording.index("case .video:", recording.index("func sendMediaRecording("))]
assert audio_send.index("enqueueMessages(account:") < audio_send.index("hasScheduleAttribute")
assert "messageIds.contains(where: { $0 != nil })" in audio_send
assert "!hasScheduleAttribute, scheduleTime == nil" in audio_send
assert "readVisibleMessagesOnSendInteraction()" in audio_send
print("PASS: accepted immediate audio-draft interaction; canceled/rejected/scheduled paths excluded")

controller = (root / "submodules/TelegramUI/Sources/ChatController.swift").read_text()
reaction_action = controller[controller.index("updateMessageReaction: { [weak self]"):controller.index("activateMessagePinch:", controller.index("updateMessageReaction: { [weak self]"))]
assert reaction_action.index("readVisibleMessagesOnSendInteraction()") < reaction_action.index("sendStarsReaction(")
assert reaction_action.rindex("readVisibleMessagesOnSendInteraction()") < reaction_action.index("updateMessageReactionsInteractively(")
print("PASS: accepted ordinary and Stars reactions trigger read-on-interaction after validation")
