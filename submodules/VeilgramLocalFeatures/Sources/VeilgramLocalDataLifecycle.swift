import Foundation

public enum VeilgramLocalDataLifecycle {
    /// Removes Veilgram-owned local data for a Telegram account that has left
    /// the active-account set. This never touches Telegram's Postbox, media
    /// cache, auth/session storage, keychain or account-manager files.
    public static func removeLoggedOutAccountData(
        accountPeerId: Int64,
        defaults: UserDefaults = .standard
    ) throws {
        let store = try VeilgramProtectedLocalStore.accountStore(accountId: accountPeerId)
        try remove(store: store, accountPeerId: accountPeerId, defaults: defaults)
    }

    static func remove(
        store: VeilgramProtectedLocalStore,
        accountPeerId: Int64,
        defaults: UserDefaults
    ) throws {
        if FileManager.default.fileExists(atPath: store.rootURL.path) {
            try FileManager.default.removeItem(at: store.rootURL)
        }

        let prefixes = [
            "veilgram.archive.runtime.v1.\(accountPeerId)",
            "veilgram.filters.runtime.v1.\(accountPeerId)",
            "veilgram.settings.v1.\(accountPeerId)"
        ]
        for key in defaults.dictionaryRepresentation().keys {
            if prefixes.contains(where: { key == $0 || key.hasPrefix($0 + ".") }) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
