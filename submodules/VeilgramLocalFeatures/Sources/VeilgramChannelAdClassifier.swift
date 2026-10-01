import Foundation

public enum VeilgramChannelAdAction: String, Codable, Equatable {
    case keep
    case label
    case collapse
}

public struct VeilgramChannelAdOptions: Equatable {
    public var enabled: Bool
    public var collapseEnabled: Bool
    public var allowedChannelIds: Set<Int64>

    public init(
        enabled: Bool = false,
        collapseEnabled: Bool = false,
        allowedChannelIds: Set<Int64> = []
    ) {
        self.enabled = enabled
        self.collapseEnabled = collapseEnabled
        self.allowedChannelIds = allowedChannelIds
    }
}

public struct VeilgramChannelAdInput: Equatable {
    public var text: String
    public var isBroadcastChannel: Bool
    public var isOfficialSponsoredMessage: Bool
    public var isServiceMessage: Bool
    public var channelId: Int64

    public init(
        text: String,
        isBroadcastChannel: Bool,
        isOfficialSponsoredMessage: Bool,
        isServiceMessage: Bool,
        channelId: Int64
    ) {
        self.text = text
        self.isBroadcastChannel = isBroadcastChannel
        self.isOfficialSponsoredMessage = isOfficialSponsoredMessage
        self.isServiceMessage = isServiceMessage
        self.channelId = channelId
    }
}

public struct VeilgramChannelAdDecision: Equatable {
    public var action: VeilgramChannelAdAction
    public var confidence: Int
    public var reasons: [String]

    public init(
        action: VeilgramChannelAdAction,
        confidence: Int = 0,
        reasons: [String] = []
    ) {
        self.action = action
        self.confidence = confidence
        self.reasons = reasons
    }
}

public enum VeilgramChannelAdClassifier {
    public static func options(
        accountId: Int64,
        defaults: UserDefaults = .standard
    ) -> VeilgramChannelAdOptions {
        let prefix = "veilgram.settings.v1.\(accountId)"
        let enabled = defaults.bool(forKey: "\(prefix).channelAdFilterEnabled")
        return VeilgramChannelAdOptions(
            enabled: enabled,
            collapseEnabled: enabled && defaults.bool(
                forKey: "\(prefix).channelAdCollapseEnabled"
            )
        )
    }

    public static func classify(
        _ input: VeilgramChannelAdInput,
        options: VeilgramChannelAdOptions
    ) -> VeilgramChannelAdDecision {
        guard options.enabled,
              input.isBroadcastChannel,
              !input.isOfficialSponsoredMessage,
              !input.isServiceMessage,
              !options.allowedChannelIds.contains(input.channelId) else {
            return VeilgramChannelAdDecision(action: .keep)
        }

        let text = input.text.lowercased()
        let hasLink = text.contains("http://")
            || text.contains("https://")
            || text.contains("t.me/")

        let hasExplicitDisclosure = [
            "#реклама",
            "на правах рекламы",
            "партнерский материал",
            "партнёрский материал",
            "advertisement",
            "paid partnership",
            "sponsored post"
        ].contains(where: { text.contains($0) })

        let hasErid = text.range(
            of: #"(?i)\berid\s*:\s*[a-z0-9]+"#,
            options: .regularExpression
        ) != nil

        let hasPromo = [
            "промокод",
            "promo code",
            "use code"
        ].contains(where: { text.contains($0) })

        let hasDiscount = [
            "скидка",
            "скидку",
            "discount",
            "special offer"
        ].contains(where: { text.contains($0) })

        let hasCallToAction = [
            "подпишитесь",
            "подписывайтесь",
            "подпишись",
            "переходите",
            "переходи",
            "забирай",
            "успей",
            "жми",
            "buy now",
            "order now",
            "shop now",
            "sign up"
        ].contains(where: { text.contains($0) })

        var confidence = 0
        var reasons: [String] = []

        if hasExplicitDisclosure {
            confidence += 2
            reasons.append("disclosure")
        }
        if hasErid {
            confidence += 2
            reasons.append("erid")
        }
        if hasPromo {
            confidence += 2
            reasons.append("promo")
        }
        if hasDiscount {
            confidence += 1
            reasons.append("discount")
        }
        if hasCallToAction {
            confidence += 1
            reasons.append("cta")
        }
        if hasLink {
            confidence += 1
            reasons.append("link")
        }

        let hasAdvertisingIdentity = hasExplicitDisclosure || hasErid || hasPromo
        guard hasAdvertisingIdentity else {
            return VeilgramChannelAdDecision(action: .keep)
        }

        if options.collapseEnabled {
            let strongDisclosureCombination =
                (hasExplicitDisclosure && hasCallToAction && hasLink)
                || (hasErid && hasExplicitDisclosure)
                || (hasPromo && hasDiscount && hasCallToAction && hasLink)
            if strongDisclosureCombination {
                return VeilgramChannelAdDecision(
                    action: .collapse,
                    confidence: confidence,
                    reasons: reasons
                )
            }
        }

        return VeilgramChannelAdDecision(
            action: .label,
            confidence: confidence,
            reasons: reasons
        )
    }
}
