import Foundation

public enum VeilgramArchiveRuntimePreferences {
    private static func prefix(accountPeerId: Int64) -> String {
        return "veilgram.archive.runtime.v1.\(accountPeerId)"
    }

    public static func messageArchiveEnabled(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return defaults.bool(
            forKey: "\(prefix(accountPeerId: accountPeerId)).deletedMessageArchive"
        )
    }

    public static func ephemeralLocalMediaEnabled(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return defaults.bool(
            forKey: "\(prefix(accountPeerId: accountPeerId)).ephemeralLocalMedia"
        )
    }

    public static func setEphemeralLocalMediaEnabled(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(
            enabled,
            forKey: "\(prefix(accountPeerId: accountPeerId)).ephemeralLocalMedia"
        )
    }

    public static func editHistoryEnabled(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) -> Bool {
        return defaults.bool(
            forKey: "\(prefix(accountPeerId: accountPeerId)).editHistory"
        )
    }

    public static func setMessageArchiveEnabled(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(
            enabled,
            forKey: "\(prefix(accountPeerId: accountPeerId)).deletedMessageArchive"
        )
    }

    public static func setEditHistoryEnabled(
        _ enabled: Bool,
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(
            enabled,
            forKey: "\(prefix(accountPeerId: accountPeerId)).editHistory"
        )
    }
}
