#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

prefs = (ROOT / "submodules/VeilgramLocalFeatures/Sources/VeilgramLocalPremiumRuntimePreferences.swift").read_text(encoding="utf-8")
context = (ROOT / "submodules/TelegramUI/Sources/AccountContext.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")

checks = []

def require(name, condition, detail):
    checks.append((name, condition, detail))

require(
    "central-effective-state",
    "effectivePresentationPremium" in prefs
    and "serverIsPremium || isEnabled" in prefs,
    "Local Premium presentation state must be centralized and preserve real server Premium.",
)
require(
    "account-context-routing",
    "VeilgramLocalPremiumRuntimePreferences.effectivePresentationPremium" in context
    and "public private(set) var isPremium" in context
    and "localPremiumObserver" in context,
    "AccountContext.isPremium must react to the local presentation preference.",
)
require(
    "server-limits-stay-server-backed",
    "Configuration.UserLimits(isPremium: isPremium)" in context
    and "let isPremium = peer?.isPremium ?? false" in context,
    "User limits must continue to be selected from the real peer Premium entitlement.",
)
require(
    "transcription-stays-server-backed",
    "AudioTranscription.TrialState" in context
    and "let isPremium = peer?.isPremium ?? false" in context,
    "Audio transcription entitlement/trial logic must remain server-backed.",
)
require(
    "settings-toggle",
    "Local Premium UI" in settings
    and "VeilgramLocalPremiumRuntimePreferences.setEnabled" in settings,
    "Veilgram settings must expose the local presentation toggle.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} Local Premium presentation-boundary checks")
