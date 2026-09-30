import Foundation

public struct VeilgramFilterRuleSummary: Equatable {
    public let id: String
    public let name: String
    public let isEnabled: Bool
    public let action: String
    public let detail: String
}

public struct VeilgramFilterRenderDecision: Equatable {
    public let ruleId: String
    public let label: String
    public let shouldCollapse: Bool

    public init(ruleId: String, label: String, shouldCollapse: Bool) {
        self.ruleId = ruleId
        self.label = label
        self.shouldCollapse = shouldCollapse
    }
}

public enum VeilgramFilterRuntime {
    private static func key(accountId: Int64) -> String {
        return "veilgram.filters.runtime.v1.\(accountId)"
    }

    static func update(
        accountId: Int64,
        document: VeilgramMessageFilterDocument,
        defaults: UserDefaults = .standard
    ) throws {
        let data = try VeilgramMessageFilterEngine.encode(document)
        defaults.set(data, forKey: key(accountId: accountId))
    }

    static func remove(
        accountId: Int64,
        defaults: UserDefaults = .standard
    ) {
        defaults.removeObject(forKey: key(accountId: accountId))
    }

    public static func evaluate(
        accountId: Int64,
        text: String,
        peerId: Int64,
        hasLink: Bool,
        isForwarded: Bool,
        defaults: UserDefaults = .standard
    ) -> VeilgramFilterRenderDecision? {
        guard let data = defaults.data(forKey: key(accountId: accountId)),
              let document = try? VeilgramMessageFilterEngine.decode(data) else {
            return nil
        }

        let matches = VeilgramMessageFilterEngine.matches(
            VeilgramMessageFilterInput(
                text: text,
                peerId: peerId,
                hasLink: hasLink,
                isForwarded: isForwarded
            ),
            document: document
        )
        guard let first = matches.first,
              let rule = document.rules.first(where: { $0.id == first.ruleId }) else {
            return nil
        }

        return VeilgramFilterRenderDecision(
            ruleId: first.ruleId,
            label: String(rule.name.prefix(48)),
            shouldCollapse: matches.contains(where: { $0.action == .collapse })
        )
    }
}

public final class VeilgramFilterStoreAPI {
    private let persistence: VeilgramMessageFilterPersistence
    private let accountId: Int64?

    public init(accountId: Int64) throws {
        self.persistence = try VeilgramMessageFilterPersistence.accountStore(accountId: accountId)
        self.accountId = accountId
        let document = try self.persistence.load()
        try VeilgramFilterRuntime.update(accountId: accountId, document: document)
    }

    init(store: VeilgramProtectedLocalStore) {
        self.persistence = VeilgramMessageFilterPersistence(store: store)
        self.accountId = nil
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
        try self.save(document)
        return id
    }

    public func setEnabled(ruleId: String, enabled: Bool) throws {
        var document = try self.persistence.load()
        guard let index = document.rules.firstIndex(where: { $0.id == ruleId }) else {
            return
        }
        document.rules[index].enabled = enabled
        try self.save(document)
    }

    public func remove(ruleId: String) throws {
        var document = try self.persistence.load()
        document.rules.removeAll(where: { $0.id == ruleId })
        try self.save(document)
    }

    public func removeAll() throws {
        try self.persistence.removeAll()
        if let accountId = self.accountId {
            VeilgramFilterRuntime.remove(accountId: accountId)
        }
    }

    public func exportData(createdAt: Int32) throws -> Data {
        return try self.persistence.exportEnvelope(
            document: self.persistence.load(),
            createdAt: createdAt
        )
    }

    public func importData(_ data: Data) throws {
        let document = try self.persistence.importAndSave(data)
        if let accountId = self.accountId {
            try VeilgramFilterRuntime.update(accountId: accountId, document: document)
        }
    }

    private func save(_ document: VeilgramMessageFilterDocument) throws {
        try self.persistence.save(document)
        if let accountId = self.accountId {
            try VeilgramFilterRuntime.update(accountId: accountId, document: document)
        }
    }
}
