import Foundation

public enum VeilgramCapturePrivacyPreferences {
    public static let didChangeNotification = Notification.Name(
        "org.veilgram.capture-privacy.changed"
    )

    private static let enabledKey = "veilgram.capturePrivacy.v1.enabled"

    public static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        return defaults.bool(forKey: enabledKey)
    }

    public static func setEnabled(
        _ enabled: Bool,
        defaults: UserDefaults = .standard
    ) {
        guard defaults.bool(forKey: enabledKey) != enabled else {
            return
        }
        defaults.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
