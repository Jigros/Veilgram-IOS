import Foundation

enum VeilgramMessageFilterAction: String, Codable, Equatable {
    case label
    case collapse
}

enum VeilgramMessageFilterMatcherKind: String, Codable, Equatable {
    case textContains
    case textRegex
    case hasLink
    case forwarded
}

struct VeilgramMessageFilterMatcher: Codable, Equatable {
    var kind: VeilgramMessageFilterMatcherKind
    var value: String?
    var caseSensitive: Bool = false
}

struct VeilgramMessageFilterRule: Codable, Equatable {
    var id: String
    var name: String
    var enabled: Bool
    var action: VeilgramMessageFilterAction
    var matchers: [VeilgramMessageFilterMatcher]
    var peerIds: [Int64] = []
    var excludedPeerIds: [Int64] = []
    var reverse: Bool = false
}

struct VeilgramMessageFilterDocument: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = currentVersion
    var rules: [VeilgramMessageFilterRule]
}

struct VeilgramMessageFilterInput {
    var text: String
    var peerId: Int64
    var hasLink: Bool
    var isForwarded: Bool
}

struct VeilgramMessageFilterMatch: Equatable {
    var ruleId: String
    var action: VeilgramMessageFilterAction
}

enum VeilgramMessageFilterError: Error, Equatable {
    case unsupportedVersion
    case tooManyRules
    case invalidRuleId
    case invalidRuleName
    case tooManyMatchers
    case invalidMatcher
    case invalidRegex
    case documentTooLarge
}

/// Purely local filter engine. It does not read Telegram storage, alter server
/// state or delete messages. Rendering code decides how a match is presented.
enum VeilgramMessageFilterEngine {
    static let maximumDocumentBytes = 256 * 1024
    static let maximumRules = 256
    static let maximumMatchersPerRule = 16
    static let maximumPatternCharacters = 512
    static let maximumInputCharacters = 16_000

    static func decode(_ data: Data) throws -> VeilgramMessageFilterDocument {
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramMessageFilterError.documentTooLarge
        }
        let document = try JSONDecoder().decode(VeilgramMessageFilterDocument.self, from: data)
        try validate(document)
        return document
    }

    static func encode(_ document: VeilgramMessageFilterDocument) throws -> Data {
        try validate(document)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= maximumDocumentBytes else {
            throw VeilgramMessageFilterError.documentTooLarge
        }
        return data
    }

    static func validate(_ document: VeilgramMessageFilterDocument) throws {
        guard document.version == VeilgramMessageFilterDocument.currentVersion else {
            throw VeilgramMessageFilterError.unsupportedVersion
        }
        guard document.rules.count <= maximumRules else {
            throw VeilgramMessageFilterError.tooManyRules
        }

        var seenIds = Set<String>()
        for rule in document.rules {
            guard !rule.id.isEmpty, rule.id.count <= 64, seenIds.insert(rule.id).inserted else {
                throw VeilgramMessageFilterError.invalidRuleId
            }
            guard !rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  rule.name.count <= 120 else {
                throw VeilgramMessageFilterError.invalidRuleName
            }
            guard !rule.matchers.isEmpty, rule.matchers.count <= maximumMatchersPerRule else {
                throw VeilgramMessageFilterError.tooManyMatchers
            }

            for matcher in rule.matchers {
                switch matcher.kind {
                case .textContains:
                    guard let value = matcher.value,
                          !value.isEmpty,
                          value.count <= maximumPatternCharacters else {
                        throw VeilgramMessageFilterError.invalidMatcher
                    }
                case .textRegex:
                    guard let value = matcher.value,
                          !value.isEmpty,
                          value.count <= maximumPatternCharacters else {
                        throw VeilgramMessageFilterError.invalidMatcher
                    }
                    do {
                        _ = try NSRegularExpression(
                            pattern: value,
                            options: matcher.caseSensitive ? [] : [.caseInsensitive]
                        )
                    } catch {
                        throw VeilgramMessageFilterError.invalidRegex
                    }
                case .hasLink, .forwarded:
                    guard matcher.value == nil || matcher.value == "" else {
                        throw VeilgramMessageFilterError.invalidMatcher
                    }
                }
            }
        }
    }

    static func matches(
        _ input: VeilgramMessageFilterInput,
        document: VeilgramMessageFilterDocument
    ) -> [VeilgramMessageFilterMatch] {
        let boundedText = String(input.text.prefix(maximumInputCharacters))
        var result: [VeilgramMessageFilterMatch] = []

        for rule in document.rules where rule.enabled {
            if rule.excludedPeerIds.contains(input.peerId) {
                continue
            }
            if !rule.peerIds.isEmpty && !rule.peerIds.contains(input.peerId) {
                continue
            }

            var matched = true
            for matcher in rule.matchers {
                if !matcherMatches(matcher, input: input, text: boundedText) {
                    matched = false
                    break
                }
            }
            if rule.reverse {
                matched.toggle()
            }
            if matched {
                result.append(VeilgramMessageFilterMatch(ruleId: rule.id, action: rule.action))
            }
        }
        return result
    }

    private static func matcherMatches(
        _ matcher: VeilgramMessageFilterMatcher,
        input: VeilgramMessageFilterInput,
        text: String
    ) -> Bool {
        switch matcher.kind {
        case .textContains:
            guard let value = matcher.value else {
                return false
            }
            if matcher.caseSensitive {
                return text.contains(value)
            } else {
                return text.range(of: value, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        case .textRegex:
            guard let pattern = matcher.value,
                  let regex = try? NSRegularExpression(
                    pattern: pattern,
                    options: matcher.caseSensitive ? [] : [.caseInsensitive]
                  ) else {
                return false
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        case .hasLink:
            return input.hasLink
        case .forwarded:
            return input.isForwarded
        }
    }
}
