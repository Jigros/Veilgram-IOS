#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

prefs = (ROOT / "submodules/VeilgramLocalFeatures/Sources/VeilgramCapturePrivacyPreferences.swift").read_text(encoding="utf-8")
app = (ROOT / "submodules/TelegramUI/Sources/AppDelegate.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")

checks = []

def require(name, condition, detail):
    checks.append((name, condition, detail))

require(
    "capture-pref",
    "VeilgramCapturePrivacyPreferences" in prefs
    and "didChangeNotification" in prefs
    and "setEnabled" in prefs,
    "Capture privacy must use an explicit local preference with change notification.",
)
require(
    "capture-observer",
    "UIScreen.capturedDidChangeNotification" in app
    and "UIScreen.main.isCaptured" in app,
    "AppDelegate must react to live screen-capture state changes.",
)
require(
    "covering-view",
    'accessibilityIdentifier = "Veilgram.CapturePrivacyCover"' in app
    and "window.addSubview(cover)" in app
    and "window.bringSubviewToFront(cover)" in app,
    "Active capture must place a dedicated opaque cover over the native app window.",
)
require(
    "cover-removal",
    "capturePrivacyCoverView?.removeFromSuperview()" in app,
    "Capture cover must be removed immediately when capture ends or the setting is disabled.",
)
require(
    "settings-toggle",
    "Hide during screen capture" in settings
    and "capturePrivacyChanged" in settings
    and "VeilgramCapturePrivacyPreferences.setEnabled" in settings,
    "Veilgram settings must expose the capture-privacy toggle.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} capture-privacy source checks")
