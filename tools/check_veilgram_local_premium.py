#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

prefs = (ROOT / "submodules/VeilgramLocalFeatures/Sources/VeilgramLocalPremiumRuntimePreferences.swift").read_text(encoding="utf-8")
context = (ROOT / "submodules/TelegramUI/Sources/AccountContext.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")
account_context_protocol = (ROOT / "submodules/AccountContext/Sources/AccountContext.swift").read_text(encoding="utf-8")
theme_settings = (ROOT / "submodules/SettingsUI/Sources/Themes/ThemeSettingsController.swift").read_text(encoding="utf-8")
profile_items = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoProfileItems.swift").read_text(encoding="utf-8")

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
    and "public private(set) var isPremiumPresentation" in context
    and "localPremiumObserver" in context
    and "var isPremiumPresentation: Bool { get }" in account_context_protocol
    and "var isPremiumPresentationSignal: Signal<Bool, NoError> { get }" in account_context_protocol
    and "isPremiumPresentationPromise" in context,
    "AccountContext must expose a separate reactive presentation-only Premium state.",
)
require(
    "server-premium-stays-real",
    "self.isPremium = isPremium" in context
    and "self.isPremiumPresentation = VeilgramLocalPremiumRuntimePreferences.effectivePresentationPremium" in context,
    "Existing AccountContext.isPremium must remain the real Telegram entitlement.",
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
require(
    "local-app-icons",
    "context.isPremiumPresentationSignal" in theme_settings
    and "isPremiumPresentationSignal" in theme_settings
    and "let isPremium = isPremiumPresentation" in theme_settings
    and "premiumConfiguration.isPremiumDisabled && !isPremiumPresentation" in theme_settings
    and "context.account.testingEnvironment" in theme_settings
    and "requestSetAlternateIconName" in theme_settings,
    "Premium app icons must react to local presentation state while preserving test-environment gating.",
)

profile_note = profile_items[profile_items.index("if let note = cachedData.note"):profile_items.index("if let botInfo = user.botInfo", profile_items.index("if let note = cachedData.note"))]
require(
    "local-note-link-formatting",
    "if context.isPremiumPresentation {" in profile_note
    and "if context.isPremium {" not in profile_note
    and "user.isPremium ? enabledPublicBioEntities" in profile_items,
    "Local Premium may enable link parsing in account-local peer notes while public bio retains server Premium.",
)

failed = [x for x in checks if not x[1]]
for name, ok, detail in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name} — {detail}")

if failed:
    raise SystemExit(1)

print(f"PASS: {len(checks)} Local Premium presentation-boundary checks")
