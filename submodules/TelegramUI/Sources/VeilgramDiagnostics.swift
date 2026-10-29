import TelegramCore

public enum VeilgramDiagnostics {
    public static func recordEvent(_ event: String, context: String, outcome: String) {
        TelegramCore.VeilgramDiagnostics.recordEvent(event, context: context, outcome: outcome)
    }

    public static func recordError(_ error: Error, context: String) {
        TelegramCore.VeilgramDiagnostics.recordError(error, context: context)
    }
}
