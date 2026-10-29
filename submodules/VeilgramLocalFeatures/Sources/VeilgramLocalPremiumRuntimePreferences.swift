import Foundation

/// Per-account switch for Veilgram-owned premium-style presentation.
///
/// This is a local UI capability. Server-authorized limits and account
/// entitlements continue to come from Telegram.
public enum VeilgramLocalPremiumRuntimePreferences {
    public static let didChangeNotification = Notification.Name(
        "org.veilgram.local-premium.changed"
    )

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

    public static func effectivePresentationPremium(
        serverIsPremium: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return serverIsPremium || isEnabled(
            accountPeerId: accountPeerId,
            defaults: defaults
        )
    }

    public static func setEnabled(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        let key = enabledKey(accountPeerId: accountPeerId)
        guard defaults.bool(forKey: key) != enabled else {
            return
        }
        defaults.set(enabled, forKey: key)
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: NSNumber(value: accountPeerId)
        )
    }
}
