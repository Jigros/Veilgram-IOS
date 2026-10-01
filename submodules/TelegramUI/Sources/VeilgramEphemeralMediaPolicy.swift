import Foundation

/// Central policy for Veilgram's ephemeral-media development harness.
///
/// Every candidate can be classified through this type, but persistent copies are
/// deliberately limited to Veilgram-owned fixtures and explicit outgoing self-tests.
/// Incoming protected/view-once media is a permanent deny case in this harness.
enum VeilgramEphemeralMediaOrigin: Equatable {
    case syntheticFixture
    case outgoingSelfTest
    case regularTelegramMedia
    case incomingViewOnce
    case secretMedia
    case copyProtected
    case paidContent
}

enum VeilgramEphemeralArchiveDecision: Equatable {
    case featureDisabled
    case allowedForTestHarness
    case notEphemeral
    case deniedProtectedIncoming
}

struct VeilgramEphemeralMediaDescriptor: Equatable {
    let origin: VeilgramEphemeralMediaOrigin
    let isEphemeral: Bool
}

enum VeilgramEphemeralMediaPolicy {
    /// Production kill switch. This intentionally ships off.
    ///
    /// Tests can exercise the enabled branch through evaluateForTesting(_:enabled:),
    /// but that path still cannot authorize incoming protected media.
    static let isFeatureEnabled = false

    static func evaluate(_ descriptor: VeilgramEphemeralMediaDescriptor) -> VeilgramEphemeralArchiveDecision {
        return evaluateForTesting(descriptor, enabled: isFeatureEnabled)
    }

    static func evaluateForTesting(
        _ descriptor: VeilgramEphemeralMediaDescriptor,
        enabled: Bool
    ) -> VeilgramEphemeralArchiveDecision {
        switch descriptor.origin {
        case .incomingViewOnce, .secretMedia, .copyProtected, .paidContent:
            return .deniedProtectedIncoming
        case .regularTelegramMedia:
            return descriptor.isEphemeral ? .deniedProtectedIncoming : .notEphemeral
        case .syntheticFixture, .outgoingSelfTest:
            guard descriptor.isEphemeral else {
                return .notEphemeral
            }
            guard enabled else {
                return .featureDisabled
            }
            return .allowedForTestHarness
        }
    }
}

enum VeilgramEphemeralArchiveOutcome: Equatable {
    case featureDisabled
    case storedForTestHarness
    case ignoredNotEphemeral
    case deniedProtectedIncoming
}

/// Small coordinator that keeps policy checks in front of the persistent store.
///
/// Callers provide already-owned bytes. This object never fetches Telegram media,
/// never weakens Gallery capture protection and never changes TTL/view-once state.
struct VeilgramEphemeralMediaArchiveCoordinator {
    let store: VeilgramProtectedLocalStore

    func archive(
        _ data: Data,
        fileName: String,
        descriptor: VeilgramEphemeralMediaDescriptor
    ) throws -> VeilgramEphemeralArchiveOutcome {
        switch VeilgramEphemeralMediaPolicy.evaluate(descriptor) {
        case .featureDisabled:
            return .featureDisabled
        case .notEphemeral:
            return .ignoredNotEphemeral
        case .deniedProtectedIncoming:
            return .deniedProtectedIncoming
        case .allowedForTestHarness:
            try store.write(data, fileName: fileName)
            return .storedForTestHarness
        }
    }

    /// Test-only entry point for exercising the enabled pipeline without changing
    /// the production kill switch. Protected incoming categories remain denied.
    func archiveForTesting(
        _ data: Data,
        fileName: String,
        descriptor: VeilgramEphemeralMediaDescriptor,
        enabled: Bool
    ) throws -> VeilgramEphemeralArchiveOutcome {
        switch VeilgramEphemeralMediaPolicy.evaluateForTesting(descriptor, enabled: enabled) {
        case .featureDisabled:
            return .featureDisabled
        case .notEphemeral:
            return .ignoredNotEphemeral
        case .deniedProtectedIncoming:
            return .deniedProtectedIncoming
        case .allowedForTestHarness:
            try store.write(data, fileName: fileName)
            return .storedForTestHarness
        }
    }
}
