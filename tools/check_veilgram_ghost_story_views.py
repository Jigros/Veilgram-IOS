#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

stories = (ROOT / "submodules/TelegramCore/Sources/TelegramEngine/Messages/Stories.swift").read_text(encoding="utf-8")
manager = (ROOT / "submodules/TelegramCore/Sources/State/ManagedSynchronizeViewStoriesOperations.swift").read_text(encoding="utf-8")
prefs = (ROOT / "submodules/VeilgramLocalFeatures/Sources/VeilgramGhostModeRuntimePreferences.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")

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

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} Ghost Mode story-view source checks")
