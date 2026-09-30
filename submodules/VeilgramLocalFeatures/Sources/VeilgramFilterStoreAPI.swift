import Foundation

public struct VeilgramFilterRuleSummary: Equatable {
    public let id: String
    public let name: String
    public let isEnabled: Bool
    public let action: String
    public let detail: String
}

public final class VeilgramFilterStoreAPI {
    private let persistence: VeilgramMessageFilterPersistence

    public init(accountId: Int64) throws {
        self.persistence = try VeilgramMessageFilterPersistence.accountStore(accountId: accountId)
    }

    init(store: VeilgramProtectedLocalStore) {
        self.persistence = VeilgramMessageFilterPersistence(store: store)
    }

    public func listRules() throws -> [VeilgramFilterRuleSummary] {
        return try self.persistence.load().rules.map { rule in
            let detail: String
            if let matcher = rule.matchers.first {
                switch matcher.kind {
                case .textContains:
                    detail = matcher.value.map { "Contains: \($0)" } ?? "Contains text"
                case .textRegex:
                    detail = matcher.value.map { "Regex: \($0)" } ?? "Regex"
                case .hasLink:
                    detail = "Has link"
                case .forwarded:
                    detail = "Forwarded message"
                }
            } else {
                detail = "No matchers"
            }
            return VeilgramFilterRuleSummary(
                id: rule.id,
                name: rule.name,
                isEnabled: rule.enabled,
                action: rule.action.rawValue,
                detail: detail
            )
        }
    }

    @discardableResult
    public func addTextContainsRule(
        name: String,
        needle: String,
        collapse: Bool = false,
        peerId: Int64? = nil
    ) throws -> String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNeedle = needle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanNeedle.isEmpty else {
            throw VeilgramMessageFilterError.invalidMatcher
        }

        var document = try self.persistence.load()
        let id = UUID().uuidString.lowercased()
        let rule = VeilgramMessageFilterRule(
            id: id,
            name: cleanName,
            enabled: true,
            action: collapse ? .collapse : .label,
            matchers: [
                VeilgramMessageFilterMatcher(
                    kind: .textContains,
                    value: cleanNeedle,
                    caseSensitive: false
                )
            ],
            peerIds: peerId.map { [$0] } ?? [],
            excludedPeerIds: [],
            reverse: false
        )
        document.rules.append(rule)
        try self.persistence.save(document)
        return id
    }

    public func setEnabled(ruleId: String, enabled: Bool) throws {
        var document = try self.persistence.load()
        guard let index = document.rules.firstIndex(where: { $0.id == ruleId }) else {
            return
        }
        document.rules[index].enabled = enabled
        try self.persistence.save(document)
    }

    public func remove(ruleId: String) throws {
        var document = try self.persistence.load()
        document.rules.removeAll(where: { $0.id == ruleId })
        try self.persistence.save(document)
    }

    public func removeAll() throws {
        try self.persistence.removeAll()
    }

    public func exportData(createdAt: Int32) throws -> Data {
        return try self.persistence.exportEnvelope(
            document: self.persistence.load(),
            createdAt: createdAt
        )
    }

    public func importData(_ data: Data) throws {
        _ = try self.persistence.importAndSave(data)
    }
}
