import Foundation

public enum VeilgramDiagnostics {
    private static var installed = false

    public static func installCrashHandlers() {
        guard !installed else { return }
        installed = true
        logAllowed("event=crash-handler-install context=startup outcome=installed")
        NSSetUncaughtExceptionHandler(veilgramUncaughtExceptionHandler)
    }

    public static func recordEvent(_ event: String, context: String, outcome: String) {
        guard let event = Event(rawValue: event),
              let context = Context(rawValue: context),
              let outcome = event.outcomes.contains(outcome) else {
            return
        }
        logAllowed("event=\(event.rawValue) context=\(context.rawValue) outcome=\(outcome)")
    }

    private static func logAllowed(_ fields: String) {
        let allowedFields = fields.split(separator: " ").filter { field in
            let parts = field.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { return false }
            switch parts[0] {
            case "event":
                return Event(rawValue: String(parts[1])) != nil || String(parts[1]) == "error"
            case "context":
                return Context(rawValue: String(parts[1])) != nil
            case "outcome":
                return Event.allCases.contains { $0.outcomes.contains(String(parts[1])) }
            case "domain":
                return [NSOSStatusErrorDomain, NSCocoaErrorDomain, "PasscodeCore.PasscodeError", "PasscodeCore", "NSURLErrorDomain", "AVFoundationErrorDomain", "other"].contains(String(parts[1]))
            case "code":
                return Int(parts[1]) != nil
            case "type":
                return ["PasscodeError", "DecodingError", "EncodingError", "NSError", "URLError", "AVError", "other"].contains(String(parts[1]))
            default:
                return false
            }
        }
        FileHandle.standardError.write(Data(("VeilgramDiagnostics \(allowedFields.joined(separator: " "))\n").utf8))
    }

    private enum Event: String, CaseIterable {
        case crashHandlerInstall = "crash-handler-install"
        case uncaughtException = "uncaught-exception"
        case officialSponsoredFilter = "official-sponsored-filter"
        case channelAdClassifier = "channel-ad-classifier"
        case channelAdRender = "channel-ad-render"
        case channelAdFilter = "channel-ad-filter"
        case channelAdCollapse = "channel-ad-collapse"
        case passcodeSetup = "passcode-setup"
        case error

        var outcomes: Set<String> {
            switch self {
            case .crashHandlerInstall:
                return ["installed"]
            case .uncaughtException:
                return ["recorded"]
            case .officialSponsoredFilter:
                return ["shown", "hidden"]
            case .channelAdClassifier:
                return ["keep", "label", "collapse"]
            case .channelAdRender:
                return ["collapsed", "labeled"]
            case .channelAdFilter, .channelAdCollapse:
                return ["enabled", "disabled"]
            case .passcodeSetup:
                return ["credential-committed", "credential-changed", "credential-updated"]
            case .error:
                return ["failed"]
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

    public static func recordError(_ error: Error, context: String) {
        guard let context = Context(rawValue: context) else { return }
        let nsError = error as NSError
        let event = "event=error context=\(context.rawValue) outcome=failed domain=\(boundedDomain(nsError.domain)) code=\(nsError.code) type=\(boundedErrorType(error))"
        logAllowed(event)
    }

    private static func boundedDomain(_ domain: String) -> String {
        let allowedDomains = [NSOSStatusErrorDomain, NSCocoaErrorDomain, "PasscodeCore.PasscodeError", "PasscodeCore", "NSURLErrorDomain", "AVFoundationErrorDomain"]
        return allowedDomains.contains(domain) ? domain : "other"
    }

    private static func boundedErrorType(_ error: Error) -> String {
        let type = String(reflecting: Swift.type(of: error))
        let allowedTypes = ["PasscodeError", "DecodingError", "EncodingError", "NSError", "URLError", "AVError"]
        return allowedTypes.first(where: { type.hasSuffix($0) }) ?? "other"
    }

    fileprivate static func recordUncaughtException(_ exception: NSException) {
        _ = exception
        logAllowed("event=uncaught-exception context=startup outcome=recorded")
        Logger.shared.sync()
    }
}

private func veilgramUncaughtExceptionHandler(_ exception: NSException) {
    VeilgramDiagnostics.recordUncaughtException(exception)
}
