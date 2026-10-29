#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
app_delegate = (ROOT / "submodules/TelegramUI/Sources/AppDelegate.swift").read_text(encoding="utf-8")
diagnostics = (ROOT / "submodules/TelegramCore/Sources/Utils/VeilgramDiagnostics.swift").read_text(encoding="utf-8")
ui_diagnostics = (ROOT / "submodules/TelegramUI/Sources/VeilgramDiagnostics.swift").read_text(encoding="utf-8")
settings_diagnostics = (ROOT / "submodules/SettingsUI/Sources/Privacy and Security/PasscodeOptionsScreen.swift").read_text(encoding="utf-8")
passcode_setup = (ROOT / "submodules/PasscodeUI/Sources/PasscodeSetupController.swift").read_text(encoding="utf-8")
gallery = (ROOT / "submodules/GalleryUI/Sources/Items/UniversalVideoGalleryItem.swift").read_text(encoding="utf-8")
gallery_build = (ROOT / "submodules/GalleryUI/BUILD").read_text(encoding="utf-8")
history = (ROOT / "submodules/TelegramUI/Sources/ChatHistoryEntriesForView.swift").read_text(encoding="utf-8")
classifier = (ROOT / "submodules/TelegramUI/Sources/VeilgramChannelAdClassifier.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")

checks = {
    "handler-after-file-logger": app_delegate.find("Logger.setSharedLogger(Logger(rootPath: rootPath, basePath: logsPath))") < app_delegate.find("TelegramCore.VeilgramDiagnostics.installCrashHandlers()"),
    "release-file-logging-disabled": "if isDebugConfiguration || buildConfig.isInternalBuild" in app_delegate and "LoggingSettings(logToFile: false, logToConsole: false, redactSensitiveData: true)" in app_delegate,
    "settings-event-api": "public static func recordEvent(_ event: String, context: String, outcome: String)" in ui_diagnostics and "TelegramCore.VeilgramDiagnostics.recordEvent(event, context: context, outcome: outcome)" in ui_diagnostics,
    "uncaught-exception-and-flush": "NSSetUncaughtExceptionHandler(veilgramUncaughtExceptionHandler)" in diagnostics and 'event=uncaught-exception context=startup outcome=recorded' in diagnostics and "exception.reason" not in diagnostics,
    "privacy-safe-error-fields": "nsError.domain" in diagnostics and "nsError.code" in diagnostics and "nsError.localizedDescription" not in diagnostics and "nsError.userInfo" not in diagnostics and "Logger.shared.log" not in diagnostics and 'case "domain":' in diagnostics and 'case "code":' in diagnostics and 'case "type":' in diagnostics,
    "passcode-failure-logging": 'TelegramCore.VeilgramDiagnostics.recordError(error, context: "passcode.setup")' in passcode_setup and 'TelegramCore.VeilgramDiagnostics.recordError(error, context: "passcode.settings.operation")' in settings_diagnostics,
    "passcode-success-logging": 'TelegramCore.VeilgramDiagnostics.recordEvent("passcode-setup", context: "settings", outcome: "credential-changed")' in settings_diagnostics,
    "video-failure-logging": 'TelegramCore.VeilgramDiagnostics.recordError(error, context: "gallery.picture-in-picture")' in gallery,
    "sponsored-post-outcomes": 'TelegramCore.VeilgramDiagnostics.recordEvent("official-sponsored-filter"' in history and 'TelegramCore.VeilgramDiagnostics.recordEvent("channel-ad-classifier"' in history and 'outcome: actionName' in history and "veilgramDecision.score" not in history and "veilgramDecision.signals" not in history,
    "settings-outcome-logging": 'TelegramCore.VeilgramDiagnostics.recordEvent("channel-ad-collapse"' in settings,
    "default-collapse-enabled": "defaults.object(forKey: collapseKey) == nil || defaults.bool(forKey: collapseKey)" in classifier,
    "gallery-does-not-import-extra-module": "import VeilgramLocalFeatures" not in gallery,
}

for name, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'}: {name}")

if not all(checks.values()):
    raise SystemExit(1)
