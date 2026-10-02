import Foundation

/// Delayed sends use Telegram's scheduled-message queue, so they survive app exit.
public enum VeilgramDelayedSendPreferences {
    public static let allowedDelays: [Int] = [0, 30, 60, 300]

    private static func key(accountPeerId: Int64) -> String {
        return "veilgram.delayedSend.v1.\(accountPeerId).seconds"
    }

    public static func seconds(accountPeerId: Int64, defaults: UserDefaults = .standard) -> Int {
        let value = defaults.integer(forKey: key(accountPeerId: accountPeerId))
        return allowedDelays.contains(value) ? value : 0
    }

    public static func setSeconds(_ value: Int, accountPeerId: Int64, defaults: UserDefaults = .standard) {
        defaults.set(allowedDelays.contains(value) ? value : 0, forKey: key(accountPeerId: accountPeerId))
    }

    public static func scheduledTimestamp(seconds: Int, now: TimeInterval = Date().timeIntervalSince1970) -> Int32? {
        guard seconds > 0, allowedDelays.contains(seconds), now.isFinite else {
            return nil
        }
        let timestamp = floor(now) + Double(seconds)
        guard timestamp > 0, timestamp < Double(Int32.max) else {
            return nil
        }
        return Int32(timestamp)
    }
}
