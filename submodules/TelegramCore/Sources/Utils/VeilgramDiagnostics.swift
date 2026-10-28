import Foundation

public enum VeilgramDiagnostics {
    private static var installed = false

    public static func installCrashHandlers() {
        guard !installed else { return }
        installed = true
        NSSetUncaughtExceptionHandler(veilgramUncaughtExceptionHandler)
        Logger.shared.log("Diagnostics", "Uncaught exception handler installed; native crashes are reported by iOS")
    }

    public static func recordEvent(_ event: String, context: String, outcome: String) {
        Logger.shared.log("Diagnostics", "Feature context=\(sanitize(context)) event=\(sanitize(event)) outcome=\(sanitize(outcome))")
    }

    public static func recordError(_ error: Error, context: String) {
        let nsError = error as NSError
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        let underlyingDetails = underlying.map { " underlyingDomain=\(sanitize($0.domain)) underlyingCode=\($0.code)" } ?? ""
        let extraDetails: String
        if nsError.domain == NSOSStatusErrorDomain {
            extraDetails = " status=\(nsError.code)"
        } else if nsError.domain == NSCocoaErrorDomain {
            extraDetails = " cocoaCode=\(nsError.code)"
        } else {
            extraDetails = ""
        }
        Logger.shared.log("Diagnostics", "Error context=\(sanitize(context)) domain=\(sanitize(nsError.domain)) code=\(nsError.code) type=\(String(reflecting: type(of: error)))\(extraDetails)\(underlyingDetails)")
    }

    public static func sanitizedContext(_ value: String) -> String {
        sanitize(value)
    }

    private static func sanitize(_ value: String) -> String {
        String(value.unicodeScalars.filter { CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._-/:" )).contains($0) }.prefix(96))
    }

    fileprivate static func recordUncaughtException(_ exception: NSException) {
        let frames = exception.callStackReturnAddresses.prefix(64).map { String($0, radix: 16) }.joined(separator: ",")
        Logger.shared.log("Diagnostics", "Uncaught exception type=exception frames=\(frames)")
        Logger.shared.sync()
    }
}

private func veilgramUncaughtExceptionHandler(_ exception: NSException) {
    VeilgramDiagnostics.recordUncaughtException(exception)
}
