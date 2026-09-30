import Foundation

@main
enum VeilgramMessageFilterTests {
    static func main() throws {
        var checks = 0

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let rule = VeilgramMessageFilterRule(
            id: "promo",
            name: "Promo posts",
            enabled: true,
            action: .label,
            matchers: [
                VeilgramMessageFilterMatcher(kind: .textContains, value: "promo", caseSensitive: false),
                VeilgramMessageFilterMatcher(kind: .hasLink, value: nil)
            ],
            peerIds: [100],
            excludedPeerIds: [],
            reverse: false
        )
        let document = VeilgramMessageFilterDocument(rules: [rule])

        let encoded = try VeilgramMessageFilterEngine.encode(document)
        let decoded = try VeilgramMessageFilterEngine.decode(encoded)
        expect(decoded == document, "round trip mismatch")

        let hit = VeilgramMessageFilterEngine.matches(
            VeilgramMessageFilterInput(text: "PROMO https://example.org", peerId: 100, hasLink: true, isForwarded: false),
            document: decoded
        )
        expect(hit == [VeilgramMessageFilterMatch(ruleId: "promo", action: .label)], "expected scoped hit")

        let noPeer = VeilgramMessageFilterEngine.matches(
            VeilgramMessageFilterInput(text: "promo", peerId: 101, hasLink: true, isForwarded: false),
            document: decoded
        )
        expect(noPeer.isEmpty, "peer scope ignored")

        let excluded = VeilgramMessageFilterRule(
            id: "exclude",
            name: "Exclude one chat",
            enabled: true,
            action: .collapse,
            matchers: [VeilgramMessageFilterMatcher(kind: .forwarded, value: nil)],
            peerIds: [],
            excludedPeerIds: [7],
            reverse: false
        )
        let excludedDoc = VeilgramMessageFilterDocument(rules: [excluded])
        expect(
            VeilgramMessageFilterEngine.matches(
                VeilgramMessageFilterInput(text: "", peerId: 7, hasLink: false, isForwarded: true),
                document: excludedDoc
            ).isEmpty,
            "excluded peer matched"
        )
        expect(
            !VeilgramMessageFilterEngine.matches(
                VeilgramMessageFilterInput(text: "", peerId: 8, hasLink: false, isForwarded: true),
                document: excludedDoc
            ).isEmpty,
            "global scope did not match"
        )

        let regex = VeilgramMessageFilterRule(
            id: "regex",
            name: "Regex",
            enabled: true,
            action: .label,
            matchers: [VeilgramMessageFilterMatcher(kind: .textRegex, value: #"\berid\s*[:=-]"#, caseSensitive: false)]
        )
        expect(
            !VeilgramMessageFilterEngine.matches(
                VeilgramMessageFilterInput(text: "ERID: abc", peerId: 1, hasLink: false, isForwarded: false),
                document: VeilgramMessageFilterDocument(rules: [regex])
            ).isEmpty,
            "regex did not match"
        )

        var reverse = regex
        reverse.id = "reverse"
        reverse.reverse = true
        expect(
            VeilgramMessageFilterEngine.matches(
                VeilgramMessageFilterInput(text: "ordinary post", peerId: 1, hasLink: false, isForwarded: false),
                document: VeilgramMessageFilterDocument(rules: [reverse])
            ).count == 1,
            "reverse rule did not invert"
        )

        var disabled = regex
        disabled.id = "disabled"
        disabled.enabled = false
        expect(
            VeilgramMessageFilterEngine.matches(
                VeilgramMessageFilterInput(text: "ERID: abc", peerId: 1, hasLink: false, isForwarded: false),
                document: VeilgramMessageFilterDocument(rules: [disabled])
            ).isEmpty,
            "disabled rule matched"
        )

        do {
            let bad = VeilgramMessageFilterRule(
                id: "bad",
                name: "Bad regex",
                enabled: true,
                action: .label,
                matchers: [VeilgramMessageFilterMatcher(kind: .textRegex, value: "(", caseSensitive: false)]
            )
            try VeilgramMessageFilterEngine.validate(VeilgramMessageFilterDocument(rules: [bad]))
            preconditionFailure("invalid regex accepted")
        } catch VeilgramMessageFilterError.invalidRegex {
            checks += 1
        }

        do {
            var duplicate = regex
            duplicate.name = "Other"
            try VeilgramMessageFilterEngine.validate(VeilgramMessageFilterDocument(rules: [regex, duplicate]))
            preconditionFailure("duplicate ids accepted")
        } catch VeilgramMessageFilterError.invalidRuleId {
            checks += 1
        }

        do {
            let unsupported = VeilgramMessageFilterDocument(version: 99, rules: [])
            _ = try VeilgramMessageFilterEngine.encode(unsupported)
            preconditionFailure("unsupported version accepted")
        } catch VeilgramMessageFilterError.unsupportedVersion {
            checks += 1
        }

        let hugeText = String(repeating: "x", count: VeilgramMessageFilterEngine.maximumInputCharacters + 1000) + "promo"
        expect(
            VeilgramMessageFilterEngine.matches(
                VeilgramMessageFilterInput(text: hugeText, peerId: 100, hasLink: true, isForwarded: false),
                document: document
            ).isEmpty,
            "input bound was not enforced"
        )

        print("PASS: \(checks) local message-filter checks")
    }
}
