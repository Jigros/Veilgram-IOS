import Foundation

/// Per-account switch for Veilgram-owned premium-style presentation.
///
/// This is a local UI capability. Server-authorized limits and account
/// entitlements continue to come from Telegram.
public enum VeilgramLocalPremiumRuntimePreferences {
    private static func prefix(accountPeerId: Int64) -> String {
        return "veilgram.localPremium.v1.\(accountPeerId)"
    }

    private static func enabledKey(accountPeerId: Int64) -> String {
        return "\(prefix(accountPeerId: accountPeerId)).enabled"
    }

    public static func isEnabled(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return defaults.bool(forKey: enabledKey(accountPeerId: accountPeerId))
    }

    public static func setEnabled(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: enabledKey(accountPeerId: accountPeerId))
    }
}
