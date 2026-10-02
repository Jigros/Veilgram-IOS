#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

stories = (ROOT / "submodules/TelegramCore/Sources/TelegramEngine/Messages/Stories.swift").read_text(encoding="utf-8")
manager = (ROOT / "submodules/TelegramCore/Sources/State/ManagedSynchronizeViewStoriesOperations.swift").read_text(encoding="utf-8")
prefs = (ROOT / "submodules/VeilgramLocalFeatures/Sources/VeilgramGhostModeRuntimePreferences.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")
interactive_read = (ROOT / "submodules/TelegramCore/Sources/TelegramEngine/Messages/InstallInteractiveReadMessagesAction.swift").read_text(encoding="utf-8")
presence = (ROOT / "submodules/TelegramCore/Sources/State/ManagedAccountPresence.swift").read_text(encoding="utf-8")
open_stories = (ROOT / "submodules/TelegramUI/Components/Stories/StoryContainerScreen/Sources/OpenStories.swift").read_text(encoding="utf-8")

checks = []

def require(name, condition, detail):
    checks.append((name, condition, detail))

require(
    "story-pref",
    "suppressStoryViews" in prefs and "setSuppressStoryViews" in prefs and ".storyViews" in prefs,
    "Ghost Mode must persist a per-account story-view suppression preference.",
)
require(
    "no-new-story-sync-op",
    "VeilgramGhostModeRuntimePreferences.suppressStoryViews" in stories
    and "_internal_addSynchronizeViewStoriesOperation" in stories,
    "markStoryAsSeen must gate creation of SynchronizeViewStoriesOperation.",
)
require(
    "queued-story-ops-dropped",
    "VeilgramGhostModeRuntimePreferences.suppressStoryViews" in manager
    and "operationLogRemoveEntry" in manager
    and "Api.functions.stories.readStories" in manager,
    "Queued story-view operations must be consumed without network readStories while suppression is active.",
)
require(
    "story-toggle-ui",
    "Hide story views" in settings
    and "ghostStoryViewsChanged" in settings
    and "setSuppressStoryViews" in settings,
    "Veilgram settings must expose the per-account story-view toggle.",
)
require(
    "manual-read-pref",
    "readOnInteractionOnly" in prefs and "setReadOnInteractionOnly" in prefs,
    "Ghost Mode must persist the manual/read-on-interaction preference.",
)
require(
    "manual-read-runtime",
    "VeilgramGhostModeRuntimePreferences.readOnInteractionOnly" in interactive_read
    and "return EmptyDisposable" in interactive_read,
    "Automatic visible-message read action must be disabled in manual-read mode.",
)
require(
    "manual-read-ui",
    "Read only on interaction" in settings
    and "ghostReadOnInteractionOnlyChanged" in settings,
    "Veilgram settings must expose the manual-read toggle.",
)
require(
    "peek-online-signal",
    "peekOnlineNotification" in prefs
    and "requestPeekOnline" in prefs,
    "Ghost Mode must expose an account-scoped one-shot Peek Online signal.",
)
require(
    "peek-online-runtime",
    "performPeekOnline" in presence
    and "updateStatus(offline: .boolFalse)" in presence
    and "timeout: 8.0" in presence
    and "updatePresence(false)" in presence,
    "Presence manager must briefly advertise online and then restore offline state.",
)
require(
    "peek-online-ui",
    "Peek Online" in settings
    and "requestPeekOnline" in settings,
    "Veilgram settings must expose the one-shot Peek Online action.",
)
require(
    "story-warning-pref",
    "warnBeforeVisibleStoryViews" in prefs
    and "setWarnBeforeVisibleStoryViews" in prefs,
    "Ghost Mode must persist the visible-story warning preference.",
)
require(
    "story-warning-runtime",
    "presentVeilgramStoryOpenWarningIfNeeded" in open_stories
    and "Ghost Mode is enabled, but Hide story views is off" in open_stories,
    "Story opening must warn before a view can be synchronized when protection is off.",
)
require(
    "story-warning-ui",
    "Warn before visible story views" in settings
    and "ghostStoryWarningChanged" in settings,
    "Veilgram settings must expose the story-open warning toggle.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} Ghost Mode story-view source checks")
