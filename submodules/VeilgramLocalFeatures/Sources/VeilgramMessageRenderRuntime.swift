import Foundation

public struct VeilgramMessageRenderDecision: Equatable {
    public let label: String
    public let shouldCollapse: Bool
    public let isAdvertisement: Bool

    public init(label: String, shouldCollapse: Bool, isAdvertisement: Bool) {
        self.label = label
        self.shouldCollapse = shouldCollapse
        self.isAdvertisement = isAdvertisement
    }
}

public enum VeilgramMessageRenderRuntime {
    private static let revealLock = NSLock()
    private static var revealedMessages = Set<String>()

    private static func settingsPrefix(accountId: Int64) -> String {
        return "veilgram.settings.v1.\(accountId)"
    }

    private static func revealKey(accountId: Int64, message: VeilgramMessageKey) -> String {
        return "\(accountId):\(message.peerId):\(message.namespace):\(message.id)"
    }

    public static func reveal(
        accountId: Int64,
        message: VeilgramMessageKey
    ) {
        revealLock.lock()
        revealedMessages.insert(revealKey(accountId: accountId, message: message))
        revealLock.unlock()
    }

    public static func isRevealed(
        accountId: Int64,
        message: VeilgramMessageKey
    ) -> Bool {
        revealLock.lock()
        let result = revealedMessages.contains(revealKey(accountId: accountId, message: message))
        revealLock.unlock()
        return result
    }

    public static func evaluate(
        accountId: Int64,
        message: VeilgramMessageKey,
        text: String,
        peerId: Int64,
        hasLink: Bool,
        isForwarded: Bool,
        isBroadcastChannel: Bool,
        isOfficialSponsored: Bool,
        isServiceMessage: Bool,
        defaults: UserDefaults = .standard
    ) -> VeilgramMessageRenderDecision? {
        if let filterDecision = VeilgramFilterRuntime.evaluate(
            accountId: accountId,
            text: text,
            peerId: peerId,
            hasLink: hasLink,
            isForwarded: isForwarded,
            defaults: defaults
        ) {
            let collapse = filterDecision.shouldCollapse
                && !isRevealed(accountId: accountId, message: message)
            return VeilgramMessageRenderDecision(
                label: filterDecision.label,
                shouldCollapse: collapse,
                isAdvertisement: false
            )
        }

        let adOptions = VeilgramChannelAdClassifier.options(
            accountId: accountId,
            defaults: defaults
        )

        let adDecision = VeilgramChannelAdClassifier.classify(
            VeilgramChannelAdInput(
                text: text,
                isBroadcastChannel: isBroadcastChannel,
                isOfficialSponsoredMessage: isOfficialSponsored,
                isServiceMessage: isServiceMessage,
                channelId: peerId
            ),
            options: adOptions
        )

        let adLabel = isOfficialSponsored ? "Sponsored message" : "Likely channel ad"
        switch adDecision.action {
        case .keep:
            return nil
        case .label:
            return VeilgramMessageRenderDecision(
                label: adLabel,
                shouldCollapse: false,
                isAdvertisement: true
            )
        case .collapse:
            return VeilgramMessageRenderDecision(
                label: adLabel,
                shouldCollapse: !isRevealed(accountId: accountId, message: message),
                isAdvertisement: true
            )
        }
    }
}
