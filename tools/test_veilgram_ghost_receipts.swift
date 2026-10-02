import Foundation

@main
enum GhostReceiptTests {
    static func main() {
        let suite = "veilgram-test-ghost-receipts-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let account: Int64 = 100
        VeilgramGhostModeRuntimePreferences.initializeDefaultsIfNeeded(accountPeerId: account, defaults: defaults)
        func suppressed(_ cloud: Bool = true, _ protocolReceipt: Bool = false, _ id: Int64 = 100) -> Bool {
            return VeilgramGhostModeRuntimePreferences.shouldSuppressContentReceipt(
                accountPeerId: id, isCloudPeer: cloud, requiresProtocolReceipt: protocolReceipt, defaults: defaults
            )
        }
        precondition(!suppressed())
        VeilgramGhostModeRuntimePreferences.setEnabled(true, accountPeerId: account, defaults: defaults)
        precondition(suppressed())
        precondition(!suppressed(false))
        precondition(!suppressed(true, true))
        precondition(!suppressed(true, false, 200))
        VeilgramGhostModeRuntimePreferences.setSuppressReadReceipts(false, accountPeerId: account, defaults: defaults)
        precondition(!suppressed())
        VeilgramGhostModeRuntimePreferences.setSuppressReadReceipts(true, accountPeerId: account, defaults: defaults)
        precondition(suppressed())
        VeilgramGhostModeRuntimePreferences.setEnabled(false, accountPeerId: account, defaults: defaults)
        precondition(!suppressed())
        print("PASS: 8 Ghost receipt account/toggle/protocol boundary checks")
    }
}
