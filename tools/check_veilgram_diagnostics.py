#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
app_delegate = (ROOT / "submodules/TelegramUI/Sources/AppDelegate.swift").read_text(encoding="utf-8")
core_diagnostics = (ROOT / "submodules/TelegramCore/Sources/Utils/VeilgramDiagnostics.swift").read_text(encoding="utf-8")
ui_diagnostics = (ROOT / "submodules/TelegramUI/Sources/VeilgramDiagnostics.swift").read_text(encoding="utf-8")
shared_diagnostics = (ROOT / "submodules/VeilgramLocalFeatures/Sources/VeilgramDiagnostics.swift").read_text(encoding="utf-8")
settings_diagnostics = (ROOT / "submodules/SettingsUI/Sources/Privacy and Security/PasscodeOptionsScreen.swift").read_text(encoding="utf-8")
passcode_setup = (ROOT / "submodules/PasscodeUI/Sources/PasscodeSetupController.swift").read_text(encoding="utf-8")
gallery = (ROOT / "submodules/GalleryUI/Sources/Items/UniversalVideoGalleryItem.swift").read_text(encoding="utf-8")
history = (ROOT / "submodules/TelegramUI/Sources/ChatHistoryEntriesForView.swift").read_text(encoding="utf-8")
classifier = (ROOT / "submodules/TelegramUI/Sources/VeilgramChannelAdClassifier.swift").read_text(encoding="utf-8")
settings = (ROOT / "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/VeilgramSettingsController.swift").read_text(encoding="utf-8")
settings_build = (ROOT / "submodules/SettingsUI/BUILD").read_text(encoding="utf-8")

checks = {
    "handler-after-file-logger": app_delegate.find("Logger.setSharedLogger(Logger(rootPath: rootPath, basePath: logsPath))") < app_delegate.find("VeilgramDiagnostics.installCrashHandlers()"),
    "release-file-logging-disabled": "if isDebugConfiguration || buildConfig.isInternalBuild" in app_delegate and "LoggingSettings(logToFile: false, logToConsole: false, redactSensitiveData: true)" in app_delegate,
    "shared-api-and-module-facades": "public static func recordEvent(_ event: String, context: String, outcome: String)" in shared_diagnostics and "func recordError(_ error: Error, context: String)" in shared_diagnostics and "VeilgramLocalFeatures.VeilgramDiagnostics.recordEvent" in core_diagnostics and "VeilgramLocalFeatures.VeilgramDiagnostics.recordEvent" in ui_diagnostics,
    "uncaught-exception-redacted": "NSSetUncaughtExceptionHandler(veilgramUncaughtExceptionHandler)" in shared_diagnostics and 'recordEvent("uncaught-exception", context: "startup", outcome: "recorded")' in shared_diagnostics and "exception.reason" not in shared_diagnostics,
    "privacy-safe-error-fields": "nsError.domain" in shared_diagnostics and "nsError.code" in shared_diagnostics and "localizedDescription" not in shared_diagnostics and "userInfo" not in shared_diagnostics and "Logger.shared.log" not in shared_diagnostics,
    "passcode-failure-logging": 'TelegramCore.VeilgramDiagnostics.recordError(error, context: "passcode.setup")' in passcode_setup and 'TelegramCore.VeilgramDiagnostics.recordError(error, context: "passcode.settings.operation")' in settings_diagnostics,
    "passcode-success-logging": 'TelegramCore.VeilgramDiagnostics.recordEvent("passcode-setup", context: "settings", outcome: "credential-changed")' in settings_diagnostics,
    "video-failure-logging": 'TelegramCore.VeilgramDiagnostics.recordError(error, context: "gallery.picture-in-picture")' in gallery,
    "sponsored-post-outcomes": 'VeilgramDiagnostics.recordEvent("official-sponsored-filter"' in history and 'VeilgramDiagnostics.recordEvent("channel-ad-classifier"' in history and 'outcome: actionName' in history and "veilgramDecision.score" not in history and "veilgramDecision.signals" not in history,
    "settings-outcome-logging": 'TelegramCore.VeilgramDiagnostics.recordEvent("channel-ad-collapse"' in settings and 'TelegramCore.VeilgramDiagnostics.recordEvent("passcode-setup"' in settings_diagnostics and "//submodules/TelegramCore:TelegramCore" in settings_build,
    "default-collapse-enabled": "defaults.object(forKey: collapseKey) == nil || defaults.bool(forKey: collapseKey)" in classifier,
}

for name, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'}: {name}")

if not all(checks.values()):
    raise SystemExit(1)
