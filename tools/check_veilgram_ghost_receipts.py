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
