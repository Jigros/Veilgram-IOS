import VeilgramLocalFeatures

public enum VeilgramDiagnostics {
    public static func installCrashHandlers() {
        VeilgramLocalFeatures.VeilgramDiagnostics.installCrashHandlers()
    }

    public static func recordEvent(_ event: String, context: String, outcome: String) {
        VeilgramLocalFeatures.VeilgramDiagnostics.recordEvent(event, context: context, outcome: outcome)
    }

    public static func recordError(_ error: Error, context: String) {
        VeilgramLocalFeatures.VeilgramDiagnostics.recordError(error, context: context)
    }
}
