#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

detail = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramLocalArchiveDetailController.swift").read_text(encoding="utf-8")
chat_view = (ROOT / "submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift").read_text(encoding="utf-8")
adapter = (ROOT / "submodules/TelegramCore/Sources/State/VeilgramArchiveStateAdapter.swift").read_text(encoding="utf-8")
writer = (ROOT / "submodules/VeilgramLocalFeatures/Sources/VeilgramArchiveRuntimeWriter.swift").read_text(encoding="utf-8")
archive_overview = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramLocalArchiveController.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")

checks = []

def require(name, condition, detail_text):
    checks.append((name, condition, detail_text))

require(
    "archive-search",
    "UISearchResultsUpdating" in detail
    and "updateSearchResults" in detail
    and "matchesSearch" in detail,
    "Archive detail UI must support local search without changing archive storage.",
)
require(
    "per-chat-filter",
    'hasPrefix("peer:")' in detail
    and "Int64(lower.dropFirst(5))" in detail,
    "Archive search must support exact peer/chat filtering.",
)
require(
    "per-message-filter",
    'hasPrefix("msg:")' in detail
    and 'searchBar.text = "peer:' in detail
    and "msg:" in detail,
    "Edit-history rows must navigate to all revisions for the selected message.",
)
require(
    "media-preview",
    "UIDocumentInteractionController" in detail
    and "archivedMediaURL" in detail
    and "UIActivityViewController" in detail,
    "Available archived media must expose a preview/share fallback.",
)
require(
    "inline-deleted",
    "veilgramDeletedBadgeNode" in chat_view
    and 'UIImage(systemName: "arrow.uturn.backward.circle.fill")' in chat_view
    and "UIColor.systemRed" not in chat_view,
    "Retained deleted messages must have an inline Deleted indicator.",
)
require(
    "inline-edits",
    "veilgramEditHistoryButtonNode" in chat_view
    and '"Edited · \\(editCount)"' in chat_view
    and 'UIImage(systemName: "pencil.circle")' in chat_view
    and "VeilgramArchiveRuntimeIndex.editRevisionCount" in chat_view
    and "veilgramEditHistoryPressed" in chat_view,
    "Messages with saved revisions must expose inline edit-history navigation.",
)
require(
    "live-edit-revisions",
    "enqueuePreviousEditRevision(" in adapter
    and "flushEditRevisions" in writer,
    "Newly captured edits must become visible immediately in inline history and remain indexed after persistence.",
)

require(
    "distinct-archive-shortcuts",
    '"Message archive"' in settings
    and '"Edit history"' in settings
    and '"Media archive"' in settings
    and "mode = .messages" in settings
    and "mode = .edits" in settings
    and "mode = .media" in settings
    and "VeilgramLocalArchiveDetailController(context: self.accountContext, mode: mode)" in settings,
    "Message, edit and media shortcuts must open their respective distinct archive detail modes.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail_text in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail_text}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} archive UI completion checks")
