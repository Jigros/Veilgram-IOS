import Foundation

public enum VeilgramGhostModeRuntimePreferences {
    public static let peekOnlineNotification = Notification.Name(
        "org.veilgram.ghost.peek-online"
    )
    public static let onlinePresenceDidChangeNotification = Notification.Name(
        "org.veilgram.ghost.online-presence-changed"
    )

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

    // Protocol receipts for expiring media and secret chats remain upstream-owned.
    public static func shouldSuppressContentReceipt(
        accountPeerId: Int64,
        isCloudPeer: Bool,
        requiresProtocolReceipt: Bool,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return isCloudPeer && !requiresProtocolReceipt
            && suppressReadReceipts(accountPeerId: accountPeerId, defaults: defaults)
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

    public static func suppressStoryViews(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return isEnabled(accountPeerId: accountPeerId, defaults: defaults)
            && defaults.bool(forKey: "\(prefix(accountPeerId: accountPeerId)).storyViews")
    }

    public static func readOnInteractionOnly(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return isEnabled(accountPeerId: accountPeerId, defaults: defaults)
            && defaults.bool(forKey: "\(prefix(accountPeerId: accountPeerId)).readOnInteractionOnly")
    }

    public static func warnBeforeVisibleStoryViews(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return isEnabled(accountPeerId: accountPeerId, defaults: defaults)
            && defaults.bool(forKey: "\(prefix(accountPeerId: accountPeerId)).warnBeforeVisibleStoryViews")
    }

    public static func setEnabled(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        let wasSuppressingOnlinePresence = suppressOnlinePresence(accountPeerId: accountPeerId, defaults: defaults)
        defaults.set(enabled, forKey: "\(prefix(accountPeerId: accountPeerId)).enabled")
        if wasSuppressingOnlinePresence != suppressOnlinePresence(accountPeerId: accountPeerId, defaults: defaults) {
            NotificationCenter.default.post(name: onlinePresenceDidChangeNotification, object: NSNumber(value: accountPeerId))
        }
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
        let wasSuppressingOnlinePresence = suppressOnlinePresence(accountPeerId: accountPeerId, defaults: defaults)
        defaults.set(enabled, forKey: "\(prefix(accountPeerId: accountPeerId)).onlinePresence")
        if wasSuppressingOnlinePresence != suppressOnlinePresence(accountPeerId: accountPeerId, defaults: defaults) {
            NotificationCenter.default.post(name: onlinePresenceDidChangeNotification, object: NSNumber(value: accountPeerId))
        }
    }

    public static func setSuppressStoryViews(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: "\(prefix(accountPeerId: accountPeerId)).storyViews")
    }

    public static func setReadOnInteractionOnly(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: "\(prefix(accountPeerId: accountPeerId)).readOnInteractionOnly")
    }

    public static func setWarnBeforeVisibleStoryViews(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: "\(prefix(accountPeerId: accountPeerId)).warnBeforeVisibleStoryViews")
    }

    public static func requestPeekOnline(accountPeerId: Int64) {
        NotificationCenter.default.post(
            name: peekOnlineNotification,
            object: NSNumber(value: accountPeerId)
        )
    }

    public static func initializeDefaultsIfNeeded(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        let readKey = "\(prefix(accountPeerId: accountPeerId)).readReceipts"
        let typingKey = "\(prefix(accountPeerId: accountPeerId)).typing"
        let presenceKey = "\(prefix(accountPeerId: accountPeerId)).onlinePresence"
        let storyViewsKey = "\(prefix(accountPeerId: accountPeerId)).storyViews"
        let readOnInteractionOnlyKey = "\(prefix(accountPeerId: accountPeerId)).readOnInteractionOnly"
        let warnBeforeVisibleStoryViewsKey = "\(prefix(accountPeerId: accountPeerId)).warnBeforeVisibleStoryViews"

        if defaults.object(forKey: readKey) == nil {
            defaults.set(true, forKey: readKey)
        }
        if defaults.object(forKey: typingKey) == nil {
            defaults.set(true, forKey: typingKey)
        }
        if defaults.object(forKey: presenceKey) == nil {
            defaults.set(true, forKey: presenceKey)
        }
        if defaults.object(forKey: storyViewsKey) == nil {
            defaults.set(true, forKey: storyViewsKey)
        }
        if defaults.object(forKey: readOnInteractionOnlyKey) == nil {
            defaults.set(false, forKey: readOnInteractionOnlyKey)
        }
        if defaults.object(forKey: warnBeforeVisibleStoryViewsKey) == nil {
            defaults.set(true, forKey: warnBeforeVisibleStoryViewsKey)
        }
    }
}
