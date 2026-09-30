"""Synthetic release guard tests. Never bundle real signing or account data."""
from pathlib import Path
import plistlib
import tempfile
import unittest
from zipfile import ZipFile

from verify_release_icon_identity import release_icon_findings


class ReleaseIconTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "fixture.ipa"
        self.good = {
            "CFBundleDisplayName": "Veilgram",
            "CFBundleIdentifier": "org.veilgram.beta",
            "CFBundleIcons": {
                "CFBundlePrimaryIcon": {
                    "CFBundleIconName": "VeilgramIcon",
                    "CFBundleIconFiles": ["Veilgram60x60"],
                },
                "CFBundleAlternateIcons": {
                    "VeilgramNight": {"CFBundleIconFiles": ["VeilgramNight"]}
                },
            },
        }

    def evaluate(self, info):
        with ZipFile(self.path, "w") as archive:
            archive.writestr("Payload/Veilgram.app/Info.plist", plistlib.dumps(info))
        return release_icon_findings(self.path)

    def test_accepts_independent_identity(self):
        self.assertEqual([], self.evaluate(self.good))

    def test_rejects_official_primary_icon(self):
        self.good["CFBundleIcons"]["CFBundlePrimaryIcon"]["CFBundleIconName"] = "Telegram"
        self.assertTrue(self.evaluate(self.good))

    def test_rejects_inherited_alternate_icon(self):
        self.good["CFBundleIcons"]["CFBundleAlternateIcons"]["BlueIcon"] = {
            "CFBundleIconFiles": ["BlueIcon"]
        }
        self.assertTrue(self.evaluate(self.good))

    def test_rejects_incorrect_bundle(self):
        self.good["CFBundleIdentifier"] = "ph.telegra.Telegraph"
        self.assertTrue(self.evaluate(self.good))

    def test_rejects_incorrect_display_name(self):
        self.good["CFBundleDisplayName"] = "Telegram"
        self.assertTrue(self.evaluate(self.good))

    def test_rejects_missing_icon_metadata(self):
        self.good.pop("CFBundleIcons")
        self.assertTrue(self.evaluate(self.good))

    def test_rejects_telegram_icon_files_even_with_other_names(self):
        self.good["CFBundleIcons"]["CFBundlePrimaryIcon"]["CFBundleIconFiles"] = ["Telegram60x60"]
        self.assertTrue(self.evaluate(self.good))


if __name__ == "__main__":
    unittest.main()
