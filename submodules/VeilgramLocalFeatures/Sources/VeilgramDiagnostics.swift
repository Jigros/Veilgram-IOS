import Foundation

public enum VeilgramDiagnostics {
    private static let installLock = NSLock()
    private static var installed = false

    public static func installCrashHandlers() {
        installLock.lock()
        defer { installLock.unlock() }
        guard !installed else { return }
        installed = true
        recordEvent("crash-handler-install", context: "startup", outcome: "installed")
        NSSetUncaughtExceptionHandler(veilgramUncaughtExceptionHandler)
    }

    public static func recordEvent(_ event: String, context: String, outcome: String) {
        guard let event = Event(rawValue: event),
              let context = Context(rawValue: context),
              event.outcomes.contains(outcome) else {
            return
        }
        write(event: event.rawValue, context: context.rawValue, outcome: outcome)
    }

    public static func recordError(_ error: Error, context: String) {
        guard let context = Context(rawValue: context) else { return }
        let nsError = error as NSError
        let allowedDomains = [NSOSStatusErrorDomain, NSCocoaErrorDomain, "PasscodeCore.PasscodeError", "PasscodeCore", "NSURLErrorDomain", "AVFoundationErrorDomain"]
        let domain = allowedDomains.contains(nsError.domain) ? nsError.domain : "other"
        let reflectedType = String(reflecting: Swift.type(of: error))
        let allowedTypes = ["PasscodeError", "DecodingError", "EncodingError", "NSError", "URLError", "AVError"]
        let type = allowedTypes.first(where: { reflectedType.hasSuffix($0) }) ?? "other"
        write(event: "error", context: context.rawValue, outcome: "failed", domain: domain, code: nsError.code, type: type)
    }

    private static func write(event: String, context: String, outcome: String, domain: String? = nil, code: Int? = nil, type: String? = nil) {
        var fields = ["event=\(event)", "context=\(context)", "outcome=\(outcome)"]
        if let domain { fields.append("domain=\(domain)") }
        if let code { fields.append("code=\(code)") }
        if let type { fields.append("type=\(type)") }
        FileHandle.standardError.write(Data(("VeilgramDiagnostics \(fields.joined(separator: " "))\n").utf8))
    }

    private enum Event: String {
        case crashHandlerInstall = "crash-handler-install"
        case uncaughtException = "uncaught-exception"
        case officialSponsoredFilter = "official-sponsored-filter"
        case channelAdClassifier = "channel-ad-classifier"
        case channelAdRender = "channel-ad-render"
        case channelAdFilter = "channel-ad-filter"
        case channelAdCollapse = "channel-ad-collapse"
        case passcodeSetup = "passcode-setup"

        var outcomes: Set<String> {
            switch self {
            case .crashHandlerInstall: return ["installed"]
            case .uncaughtException: return ["recorded"]
            case .officialSponsoredFilter: return ["shown", "hidden"]
            case .channelAdClassifier: return ["keep", "label", "collapse"]
            case .channelAdRender: return ["collapsed", "labeled"]
            case .channelAdFilter, .channelAdCollapse: return ["enabled", "disabled"]
            case .passcodeSetup: return ["credential-committed", "credential-changed", "credential-updated"]
            }
        }
    }

    private enum Context: String {
        case startup
        case chatHistory = "chat.history"
        case messageItem = "message.item"
        case settings
        case passcodeSetup = "passcode.setup"
        case passcodeSettingsOperation = "passcode.settings.operation"
        case galleryPictureInPicture = "gallery.picture-in-picture"
    }

    fileprivate static func recordUncaughtException(_ exception: NSException) {
        _ = exception
        recordEvent("uncaught-exception", context: "startup", outcome: "recorded")
        FileHandle.standardError.synchronizeFile()
    }
}

private func veilgramUncaughtExceptionHandler(_ exception: NSException) {
    VeilgramDiagnostics.recordUncaughtException(exception)
}
