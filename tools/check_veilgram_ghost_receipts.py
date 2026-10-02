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
