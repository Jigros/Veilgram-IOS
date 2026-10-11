import Foundation

@main
enum VeilgramChannelAdClassifierTests {
    static func main() {
        var tests = 0

        func check(
            _ text: String,
            channel: Bool = true,
            official: Bool = false,
            service: Bool = false,
            channelId: Int64 = 9,
            options: VeilgramChannelAdOptions,
            action: VeilgramChannelAdAction
        ) {
            let item = VeilgramChannelAdInput(
                text: text,
                isBroadcastChannel: channel,
                isOfficialSponsoredMessage: official,
                isServiceMessage: service,
                channelId: channelId
            )
            let decision = VeilgramChannelAdClassifier.classify(item, options: options)
            precondition(decision.action == action, "Unexpected ad filter result for \(text): \(decision.action)")
            tests += 1
        }

        let disabled = VeilgramChannelAdOptions()
        var label = VeilgramChannelAdOptions()
        label.enabled = true
        var collapse = label
        collapse.collapseEnabled = true

        let suite = "veilgram-adfilter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var persisted = VeilgramChannelAdClassifier.options(accountId: 77, defaults: defaults)
        precondition(!persisted.enabled && !persisted.collapseEnabled)
        defaults.set(true, forKey: "veilgram.settings.v1.77.channelAdFilterEnabled")
        defaults.set(true, forKey: "veilgram.settings.v1.77.channelAdCollapseEnabled")
        persisted = VeilgramChannelAdClassifier.options(accountId: 77, defaults: defaults)
        precondition(persisted.enabled && persisted.collapseEnabled)
        defaults.set(false, forKey: "veilgram.settings.v1.77.channelAdFilterEnabled")
        persisted = VeilgramChannelAdClassifier.options(accountId: 77, defaults: defaults)
        precondition(!persisted.enabled && !persisted.collapseEnabled)
        tests += 3

        check("#реклама erid:abcdef123", options: disabled, action: .keep)
        check("#реклама erid:abcdef123", official: true, options: collapse, action: .collapse)
        check("Telegram sponsored", official: true, options: label, action: .label)
        check("#реклама erid:abcdef123", channel: false, options: collapse, action: .keep)
        check("#реклама erid:abcdef123", service: true, options: collapse, action: .keep)
        check("Закон о рекламе изменился", options: collapse, action: .keep)
        check("Обзор рекламного рынка https://example.org", options: collapse, action: .keep)
        check("Новая версия приложения доступна сегодня", options: collapse, action: .keep)
        check("Реклама появилась на витринах магазинов", options: collapse, action: .keep)
        check("На правах рекламы: новая коллекция", options: label, action: .label)
        check("На правах рекламы: новая коллекция", options: collapse, action: .label)
        check("На правах рекламы: подпишитесь https://example.org", options: collapse, action: .collapse)
        check("Промокод SAVE, скидка 20%, переходите по ссылке https://example.org", options: collapse, action: .collapse)
        check("erid:2VtzqwpZ8x1", options: collapse, action: .label)
        check("ERID:2VtzqwpZ8x1 #РЕКЛАМА", options: collapse, action: .collapse)
        collapse.allowedChannelIds = [9]
        check("На правах рекламы: подпишитесь https://example.org", options: collapse, action: .keep)
        check("На правах рекламы: подпишитесь https://example.org", channelId: 7, options: collapse, action: .collapse)

        let runtimeSuite = "veilgram-render-runtime-\(UUID().uuidString)"
        let runtimeDefaults = UserDefaults(suiteName: runtimeSuite)!
        defer { runtimeDefaults.removePersistentDomain(forName: runtimeSuite) }
        let runtimeAccount: Int64 = 7001
        runtimeDefaults.set(true, forKey: "veilgram.settings.v1.\(runtimeAccount).channelAdFilterEnabled")
        runtimeDefaults.set(true, forKey: "veilgram.settings.v1.\(runtimeAccount).channelAdCollapseEnabled")

        let sponsoredKey = VeilgramMessageKey(peerId: 9001, namespace: 0, id: 101)
        var decision = VeilgramMessageRenderRuntime.evaluate(
            accountId: runtimeAccount,
            message: sponsoredKey,
            text: "Sponsored",
            peerId: sponsoredKey.peerId,
            hasLink: false,
            isForwarded: false,
            isBroadcastChannel: true,
            isOfficialSponsored: true,
            isServiceMessage: false,
            defaults: runtimeDefaults
        )
        precondition(decision?.isAdvertisement == true)
        precondition(decision?.label == "Sponsored message")
        precondition(decision?.shouldCollapse == true)

        VeilgramMessageRenderRuntime.reveal(
            accountId: runtimeAccount,
            message: sponsoredKey
        )
        decision = VeilgramMessageRenderRuntime.evaluate(
            accountId: runtimeAccount,
            message: sponsoredKey,
            text: "Sponsored",
            peerId: sponsoredKey.peerId,
            hasLink: false,
            isForwarded: false,
            isBroadcastChannel: true,
            isOfficialSponsored: true,
            isServiceMessage: false,
            defaults: runtimeDefaults
        )
        precondition(decision?.shouldCollapse == false)

        let neighboringKey = VeilgramMessageKey(peerId: 9001, namespace: 0, id: 102)
        let neighborDecision = VeilgramMessageRenderRuntime.evaluate(
            accountId: runtimeAccount,
            message: neighboringKey,
            text: "Sponsored",
            peerId: neighboringKey.peerId,
            hasLink: false,
            isForwarded: false,
            isBroadcastChannel: true,
            isOfficialSponsored: true,
            isServiceMessage: false,
            defaults: runtimeDefaults
        )
        precondition(neighborDecision?.shouldCollapse == true)

        let otherAccountDecision = VeilgramMessageRenderRuntime.evaluate(
            accountId: runtimeAccount + 1,
            message: sponsoredKey,
            text: "Sponsored",
            peerId: sponsoredKey.peerId,
            hasLink: false,
            isForwarded: false,
            isBroadcastChannel: true,
            isOfficialSponsored: true,
            isServiceMessage: false,
            defaults: runtimeDefaults
        )
        precondition(otherAccountDecision == nil)
        tests += 7

        print("PASS: \(tests) deterministic privacy-safe native ad-classifier checks")
    }
}
