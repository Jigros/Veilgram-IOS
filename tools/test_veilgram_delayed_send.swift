import Foundation

@main
struct DelayedSendTests {
    static func main() {
        let suite = "veilgram.delayedSend.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(VeilgramDelayedSendPreferences.seconds(accountPeerId: 1, defaults: defaults) == 0)
        for seconds in [30, 60, 300] {
            VeilgramDelayedSendPreferences.setSeconds(seconds, accountPeerId: 1, defaults: defaults)
            precondition(VeilgramDelayedSendPreferences.seconds(accountPeerId: 1, defaults: defaults) == seconds)
            precondition(VeilgramDelayedSendPreferences.seconds(accountPeerId: 2, defaults: defaults) == 0)
            let reopened = UserDefaults(suiteName: suite)!
            precondition(VeilgramDelayedSendPreferences.seconds(accountPeerId: 1, defaults: reopened) == seconds)
            precondition(VeilgramDelayedSendPreferences.scheduledTimestamp(seconds: seconds, now: 1000.9) == Int32(1000 + seconds))
        }
        for seconds in [-1, 0, 1, Int.max] {
            VeilgramDelayedSendPreferences.setSeconds(seconds, accountPeerId: 1, defaults: defaults)
            precondition(VeilgramDelayedSendPreferences.seconds(accountPeerId: 1, defaults: defaults) == 0)
            precondition(VeilgramDelayedSendPreferences.scheduledTimestamp(seconds: seconds, now: 1000) == nil)
        }
        defaults.set(999, forKey: "veilgram.delayedSend.v1.1.seconds")
        precondition(VeilgramDelayedSendPreferences.seconds(accountPeerId: 1, defaults: defaults) == 0)
        precondition(VeilgramDelayedSendPreferences.scheduledTimestamp(seconds: 30, now: .infinity) == nil)
        precondition(VeilgramDelayedSendPreferences.scheduledTimestamp(seconds: 30, now: .nan) == nil)
        precondition(VeilgramDelayedSendPreferences.scheduledTimestamp(seconds: 30, now: Double(Int32.max) - 10) == nil)
        print("PASS: delayed send defaults, persistence, account isolation, invalid values and timestamp bounds")
    }
}
