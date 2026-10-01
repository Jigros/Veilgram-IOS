import Foundation

public enum VeilgramGhostModeRuntimePreferences {
    private static func prefix(accountPeerId: Int64) -> String {
        return "veilgram.ghost.runtime.v1.\(accountPeerId)"
    }

    public static func isEnabled(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return defaults.bool(forKey: "\(prefix(accountPeerId: accountPeerId)).enabled")
    }

    public static func suppressReadReceipts(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return isEnabled(accountPeerId: accountPeerId, defaults: defaults)
            && defaults.bool(forKey: "\(prefix(accountPeerId: accountPeerId)).readReceipts")
    }

    public static func suppressTyping(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return isEnabled(accountPeerId: accountPeerId, defaults: defaults)
            && defaults.bool(forKey: "\(prefix(accountPeerId: accountPeerId)).typing")
    }

    public static func suppressOnlinePresence(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return isEnabled(accountPeerId: accountPeerId, defaults: defaults)
            && defaults.bool(forKey: "\(prefix(accountPeerId: accountPeerId)).onlinePresence")
    }

    public static func setEnabled(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: "\(prefix(accountPeerId: accountPeerId)).enabled")
    }

    public static func setSuppressReadReceipts(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: "\(prefix(accountPeerId: accountPeerId)).readReceipts")
    }

    public static func setSuppressTyping(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: "\(prefix(accountPeerId: accountPeerId)).typing")
    }

    public static func setSuppressOnlinePresence(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: "\(prefix(accountPeerId: accountPeerId)).onlinePresence")
    }

    public static func initializeDefaultsIfNeeded(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        let readKey = "\(prefix(accountPeerId: accountPeerId)).readReceipts"
        let typingKey = "\(prefix(accountPeerId: accountPeerId)).typing"
        let presenceKey = "\(prefix(accountPeerId: accountPeerId)).onlinePresence"

        if defaults.object(forKey: readKey) == nil {
            defaults.set(true, forKey: readKey)
        }
        if defaults.object(forKey: typingKey) == nil {
            defaults.set(true, forKey: typingKey)
        }
        if defaults.object(forKey: presenceKey) == nil {
            defaults.set(true, forKey: presenceKey)
        }
    }
}
