import Foundation

@main
enum VeilgramAdFilterCorpusTests {
    struct Sample {
        let text: String
        let expectedAd: Bool
        let collapseAllowed: Bool
    }

    static func main() {
        var options = VeilgramChannelAdOptions()
        options.enabled = true
        options.collapseEnabled = true

        let samples: [Sample] = [
            .init(text: "Сегодня в городе открылся новый парк", expectedAd: false, collapseAllowed: false),
            .init(text: "Курс валют и главные новости дня", expectedAd: false, collapseAllowed: false),
            .init(text: "Закон о рекламе изменился: что нужно знать бизнесу", expectedAd: false, collapseAllowed: false),
            .init(text: "Рекламный рынок вырос на 8 процентов по итогам года", expectedAd: false, collapseAllowed: false),
            .init(text: "Advertising industry report: market grew this quarter", expectedAd: false, collapseAllowed: false),
            .init(text: "Обзор приложения без партнерских ссылок", expectedAd: false, collapseAllowed: false),
            .init(text: "Новая версия доступна по ссылке https://example.org", expectedAd: false, collapseAllowed: false),
            .init(text: "Подпишитесь на обновления канала", expectedAd: false, collapseAllowed: false),
            .init(text: "Скидка инфляции составила 5 процентов — аналитика", expectedAd: false, collapseAllowed: false),
            .init(text: "ERID как идентификатор интернет-рекламы: разбор закона", expectedAd: false, collapseAllowed: false),

            .init(text: "#реклама Новая коллекция уже в продаже", expectedAd: true, collapseAllowed: false),
            .init(text: "На правах рекламы: новый сервис доставки", expectedAd: true, collapseAllowed: false),
            .init(text: "erid:2VtzqwpZ8x1", expectedAd: true, collapseAllowed: false),
            .init(text: "Paid partnership with Example Brand", expectedAd: true, collapseAllowed: false),
            .init(text: "Партнерская ссылка: https://example.org/?ref=me", expectedAd: true, collapseAllowed: true),
            .init(text: "#реклама Подпишитесь и переходите по ссылке https://example.org", expectedAd: true, collapseAllowed: true),
            .init(text: "Промокод SAVE, скидка 20%, переходите по ссылке https://example.org", expectedAd: true, collapseAllowed: true),
            .init(text: "Sponsored post — shop now https://example.org", expectedAd: true, collapseAllowed: true),
            .init(text: "Рекламная интеграция: получите бонус по промокоду START", expectedAd: true, collapseAllowed: true),
            .init(text: "Affiliate offer, use promo code TEST https://example.org", expectedAd: true, collapseAllowed: true)
        ]

        var falsePositives = 0
        var falseNegatives = 0
        var unsafeCollapses = 0

        for sample in samples {
            let decision = VeilgramChannelAdClassifier.classify(
                VeilgramChannelAdInput(
                    text: sample.text,
                    isBroadcastChannel: true,
                    isOfficialSponsoredMessage: false,
                    isServiceMessage: false,
                    channelId: 1
                ),
                options: options
            )
            let detected = decision.action != .keep
            if detected && !sample.expectedAd {
                falsePositives += 1
                print("FP: \(sample.text) | score=\(decision.score) signals=\(decision.signals)")
            }
            if !detected && sample.expectedAd {
                falseNegatives += 1
                print("FN: \(sample.text)")
            }
            if decision.action == .collapse && !sample.collapseAllowed {
                unsafeCollapses += 1
                print("UNSAFE COLLAPSE: \(sample.text)")
            }
        }

        precondition(falsePositives == 0, "synthetic corpus produced false positives")
        precondition(falseNegatives == 0, "synthetic corpus missed explicit advertising samples")
        precondition(unsafeCollapses == 0, "collapse triggered outside high-confidence synthetic cases")
        print("PASS: \(samples.count) synthetic ad-filter corpus samples, 0 FP / 0 FN / 0 unsafe collapses")
    }
}
