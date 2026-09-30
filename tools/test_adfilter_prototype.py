import unittest
from adfilter_prototype import Post, Configuration, classify


class ChannelAdFilterTests(unittest.TestCase):
    def setUp(self):
        self.label = Configuration(enabled=True)
        self.collapse = Configuration(enabled=True, mode="collapse")

    def test_disabled_is_pure_passthrough(self):
        ad = Post("Рекламная интеграция #реклама erid:abcdef123", True, channel_id=101)
        self.assertEqual("keep", classify(ad, Configuration()).action)

    def test_official_ads_never_touched(self):
        for cfg in (self.label, self.collapse):
            d = classify(Post("Спонсор реклама #реклама erid:abcdef123", True, is_official_sponsored=True), cfg)
            self.assertEqual(("keep", 0), (d.action, d.score))

    def test_only_channel_posts(self):
        for kind in (Post("#реклама промокод TEST по ссылке https://example.org", False),
                     Post("#реклама", True, is_service=True)):
            self.assertEqual("keep", classify(kind, self.collapse).action)

    def test_disclosed_paid_post(self):
        d = classify(Post("Партнерский материал: продукт недели", True), self.collapse)
        self.assertEqual("label", d.action)
        self.assertIn("disclosure", d.signals)

    def test_erid_is_strong(self):
        d = classify(Post("erid:2VtzqwpZ8x1", True), self.collapse)
        self.assertEqual("collapse", d.action)

    def test_multi_signal_ad(self):
        s = "Подпишитесь и получите скидку 20%, промокод LOVE20 https://shop.example/test"
        d = classify(Post(s, True), self.collapse)
        self.assertEqual("collapse", d.action)
        self.assertIn("promo", d.signals)

    def test_news_about_ads_retained(self):
        texts = [
            "Правительство обсуждает закон о рекламе и регулирование рекламы на рынке",
            "В статье объясняем, как устроена реклама в приложениях",
            "Исследование рекламного рынка — ссылка на первоисточник https://example.org",
            "Реклама стала причиной общественной дискуссии",
            "Сегодня вышла новая версия нашего приложения. Спасибо за поддержку!",
            "Разработчики выпустили обновление с поддержкой чатов.",
        ]
        for item in texts:
            with self.subTest(item=item):
                self.assertEqual("keep", classify(Post(item, True), self.collapse).action)

    def test_allowlist(self):
        d = classify(Post("#реклама erid:abcdef123", True, channel_id=55),
                     Configuration(enabled=True, mode="collapse",
                                   allowed_channels=frozenset({55})))
        self.assertEqual("keep", d.action)

    def test_label_mode_never_collapses(self):
        self.assertEqual("label", classify(
            Post("#реклама erid:abcdef123 https://example.com", True), self.label).action)

    def test_unknown_mode_rejected_when_enabled(self):
        with self.assertRaises(ValueError):
            classify(Post("#реклама", True), Configuration(enabled=True, mode="oops"))

    def test_obfuscated_markers_and_case(self):
        p = Post("＃РЕКЛАМА • еrіd:abcdef123", True)
        self.assertEqual("keep", classify(p, self.collapse).action)  # Unicode homoglyphs need ML/extra rules


if __name__ == "__main__":
    unittest.main()
