import Foundation

public enum VeilgramSendConfirmationPreferences {
    private static func key(accountPeerId: Int64) -> String {
        return "veilgram.sendConfirmation.v1.\(accountPeerId).enabled"
    }

    public static func isEnabled(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return defaults.bool(forKey: key(accountPeerId: accountPeerId))
    }

    public static func setEnabled(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: key(accountPeerId: accountPeerId))
    }
}
