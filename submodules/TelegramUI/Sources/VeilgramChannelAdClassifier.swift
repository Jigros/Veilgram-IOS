import Foundation

/// Local, opt-in heuristic for ordinary broadcast-channel posts only.
/// Never use this to process Telegram's own Sponsored Messages.
/// No network access, content retention, account identifiers or telemetry.
enum VeilgramChannelAdAction: Equatable {
    case keep
    case label
    case collapse
}

struct VeilgramChannelAdInput {
    let text: String
    let isBroadcastChannel: Bool
    let isOfficialSponsoredMessage: Bool
    let isServiceMessage: Bool
    let channelId: Int64
}

struct VeilgramChannelAdOptions {
    var enabled: Bool = false
    var collapseEnabled: Bool = false
    var allowedChannelIds: Set<Int64> = []
    var suspectedThreshold: Int = 6
    var collapseThreshold: Int = 9
}

struct VeilgramChannelAdDecision {
    let action: VeilgramChannelAdAction
    let score: Int
    let signals: [String]

    static var passthrough: VeilgramChannelAdDecision {
        return VeilgramChannelAdDecision(action: .keep, score: 0, signals: [])
    }
}

enum VeilgramChannelAdClassifier {
    static func options(accountId: Int64, defaults: UserDefaults = .standard) -> VeilgramChannelAdOptions {
        let prefix = "veilgram.settings.v1.\(accountId)"
        let enabled = defaults.bool(forKey: "\(prefix).channelAdFilterEnabled")
        let collapse = enabled && defaults.bool(forKey: "\(prefix).channelAdCollapseEnabled")
        return VeilgramChannelAdOptions(
            enabled: enabled,
            collapseEnabled: collapse,
            allowedChannelIds: [],
            suspectedThreshold: 6,
            collapseThreshold: 9
        )
    }

    private struct Rule {
        let name: String
        let points: Int
        let pattern: NSRegularExpression

        init(_ name: String, _ points: Int, _ expression: String) {
            self.name = name
            self.points = points
            // Literal, developer-controlled regex; no user-provided pattern.
            self.pattern = try! NSRegularExpression(pattern: expression, options: [.caseInsensitive])
        }

        func matches(_ text: String) -> Bool {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return self.pattern.firstMatch(in: text, options: [], range: range) != nil
        }
    }

    private static let rules: [Rule] = [
        Rule("disclosure", 8, #"(?:#(?:реклам[а-яё]*|интеграци[а-яё]*|спонсор[а-яё]*|партн[её]рск[а-яё]*|sponsored|advertisement|paidpartnership)\b|\b(?:на правах рекламы|рекламная интеграция|партн[её]рский материал|paid partnership|sponsored post)\b)"#),
        Rule("erid", 9, #"\berid\s*[:=\-]\s*[a-z0-9][a-z0-9_\-]{5,}\b"#),
        Rule("promo", 3, #"\b(?:промокод(?:ом|а|ы)?|по промокоду|скидка по коду|use (?:promo|discount) code)\b"#),
        Rule("offer", 2, #"\b(?:скидк[ауи]\s+\d{1,2}\s*(?:%|процентов)(?=\W|$)|специальное предложение|limited time offer|получи бонус)(?=\W|$)"#),
        Rule("call_to_action", 2, #"\b(?:подписывайтесь|подпишитесь|успейте купить|переходите по ссылке|заказывайте|купите сейчас|shop now|sign up now)\b"#),
        Rule("affiliate", 5, #"\b(?:партн[её]рская ссылка|реферальная ссылка|мой реф(?:еральный)?(?: код)?|affiliate)\b|\b(?:ref|aff|utm_medium)\s*="#),
        Rule("link", 2, #"(?:https?://|(?:^|\s)t\.me/|(?:^|\s)@[a-z][a-z0-9_]{4,})"#)
    ]

    private static let discussion = Rule(
        "discussion", 0,
        #"\b(?:закон(?:опроект)? о рекламе|регулировани[ея] рекламы|рекламн(?:ый|ого) рынок|ad regulation|advertising industry)\b"#
    )

    static func classify(
        _ input: VeilgramChannelAdInput,
        options: VeilgramChannelAdOptions
    ) -> VeilgramChannelAdDecision {
        guard options.enabled,
              input.isBroadcastChannel,
              !input.isOfficialSponsoredMessage,
              !input.isServiceMessage,
              !options.allowedChannelIds.contains(input.channelId) else {
            return .passthrough
        }

        // Bounded local work, no external classification services.
        let text = String(input.text.prefix(16_000))
            .precomposedStringWithCompatibilityMapping
            .lowercased()
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{200C}", with: "")
            .replacingOccurrences(of: "\u{200D}", with: "")

        var score = 0
        var signals: [String] = []
        for rule in rules {
            if rule.matches(text) {
                score += rule.points
                signals.append(rule.name)
            }
        }

        if discussion.matches(text) &&
           !signals.contains("disclosure") &&
           !signals.contains("erid") {
            score = max(0, score - 3)
        }
        let action: VeilgramChannelAdAction
        if score < options.suspectedThreshold {
            action = .keep
        } else if options.collapseEnabled &&
                  score >= options.collapseThreshold &&
                  signals.count >= 2 {
            // Multiple independent cues required before obscuring a post.
            action = .collapse
        } else {
            action = .label
        }
        return VeilgramChannelAdDecision(action: action, score: score, signals: signals)
    }
}
