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

        let prefix = settingsPrefix(accountId: accountId)
        let detectionEnabled = defaults.bool(
            forKey: "\(prefix).channelAdFilterEnabled"
        )
        guard detectionEnabled && (isBroadcastChannel || isOfficialSponsored) else {
            return nil
        }

        if isOfficialSponsored {
            let collapse = defaults.bool(
                forKey: "\(prefix).channelAdCollapseEnabled"
            ) && !isRevealed(accountId: accountId, message: message)
            return VeilgramMessageRenderDecision(
                label: "Sponsored message",
                shouldCollapse: collapse,
                isAdvertisement: true
            )
        }

        let normalized = text.lowercased()
        var score = 0

        let explicitMarkers = [
            "#реклама",
            "рекламный пост",
            "на правах рекламы",
            "партнерский материал",
            "партнёрский материал",
            "advertisement",
            "sponsored post",
            "paid partnership"
        ]
        if explicitMarkers.contains(where: { normalized.contains($0) }) {
            score += 3
        }

        let promoMarkers = [
            "промокод",
            "по промокоду",
            "скидка",
            "скидку",
            "купи",
            "купить",
            "заказать",
            "promo code",
            "discount",
            "use code",
            "special offer"
        ]
        if promoMarkers.contains(where: { normalized.contains($0) }) {
            score += 2
        }

        let callToActionMarkers = [
            "переходи",
            "переходите",
            "подписывайся",
            "подписывайтесь",
            "успей",
            "забирай",
            "жми",
            "order now",
            "buy now",
            "sign up",
            "shop now"
        ]
        if callToActionMarkers.contains(where: { normalized.contains($0) }) {
            score += 1
        }

        if hasLink {
            score += 1
        }

        guard score >= 3 else {
            return nil
        }

        let collapse = defaults.bool(
            forKey: "\(prefix).channelAdCollapseEnabled"
        ) && !isRevealed(accountId: accountId, message: message)

        return VeilgramMessageRenderDecision(
            label: "Likely channel ad",
            shouldCollapse: collapse,
            isAdvertisement: true
        )
    }
}
