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
        VeilgramGhostModeRuntimePreferences.setSuppressReadReceipts(true, accountPeerId: account, defaults: defaults)
        VeilgramGhostModeRuntimePreferences.setEnabled(true, accountPeerId: account, defaults: defaults)
        let mixedReceipts = [
            (id: Int64(1), isCloud: true, requiresProtocol: false),
            (id: Int64(2), isCloud: true, requiresProtocol: true),
            (id: Int64(3), isCloud: false, requiresProtocol: false),
            (id: Int64(4), isCloud: true, requiresProtocol: false)
        ]
        let retainedReceipts = mixedReceipts.filter {
            !VeilgramGhostModeRuntimePreferences.shouldSuppressContentReceipt(
                accountPeerId: account,
                isCloudPeer: $0.isCloud,
                requiresProtocolReceipt: $0.requiresProtocol,
                defaults: defaults
            )
        }
        precondition(retainedReceipts.map(\.id) == [2, 3])
        VeilgramGhostModeRuntimePreferences.setEnabled(false, accountPeerId: account, defaults: defaults)
        precondition(!suppressed())
        print("PASS: account/toggle/protocol and mixed-queue receipt boundary checks")
    }
}
