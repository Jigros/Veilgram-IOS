import Foundation

/// Client-local presentation preference for Veilgram-owned premium-style UI.
///
/// This intentionally does not alter Telegram account entitlement, API limits,
/// paid reactions, upload limits, stories limits, or any other server-authorized
/// Premium capability.
public enum VeilgramLocalPremiumRuntimePreferences {
    private static func prefix(accountPeerId: Int64) -> String {
        return "veilgram.localPremium.v1.\(accountPeerId)"
    }

    private static func enabledKey(accountPeerId: Int64) -> String {
        return "\(prefix(accountPeerId: accountPeerId)).enabled"
    }

    private static func initializedKey(accountPeerId: Int64) -> String {
        return "\(prefix(accountPeerId: accountPeerId)).initialized"
    }

    public static func initializeDefaultsIfNeeded(accountPeerId: Int64) {
        let defaults = UserDefaults.standard
        let initialized = initializedKey(accountPeerId: accountPeerId)
        if !defaults.bool(forKey: initialized) {
            defaults.set(false, forKey: enabledKey(accountPeerId: accountPeerId))
            defaults.set(true, forKey: initialized)
        }
    }

    public static func isEnabled(accountPeerId: Int64) -> Bool {
        initializeDefaultsIfNeeded(accountPeerId: accountPeerId)
        return UserDefaults.standard.bool(forKey: enabledKey(accountPeerId: accountPeerId))
    }

    public static func setEnabled(_ value: Bool, accountPeerId: Int64) {
        initializeDefaultsIfNeeded(accountPeerId: accountPeerId)
        UserDefaults.standard.set(value, forKey: enabledKey(accountPeerId: accountPeerId))
    }
}
