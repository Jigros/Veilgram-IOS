#!/usr/bin/env python3
"""Synthetic fixture tests for verify_device_ipa, no Xcode required."""
import io
import plistlib
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

from verify_device_ipa import ARM64, inspect


def executable(platform, cpu=ARM64):
    header = struct.pack("<IIIIIIII", 0xfeedfacf, cpu, 0, 2, 1, 24, 0, 0)
    command = struct.pack("<IIIIII", 0x32, 24, platform, 0, 0, 0)
    return header + command


def fixture(path, platform=2, extension_platform=2, extension_id="org.veilgram.buildtwo.Share"):
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("Payload/Veilgram.app/Info.plist", plistlib.dumps({
            "CFBundleIdentifier": "org.veilgram.buildtwo", "CFBundleExecutable": "Veilgram"}))
        z.writestr("Payload/Veilgram.app/Veilgram", executable(platform))
        z.writestr("Payload/Veilgram.app/PlugIns/Share.appex/Info.plist", plistlib.dumps({
            "CFBundleIdentifier": extension_id, "CFBundleExecutable": "Share"}))
        z.writestr("Payload/Veilgram.app/PlugIns/Share.appex/Share", executable(extension_platform))


class DeviceIPATests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "test.ipa"

    def tearDown(self):
        self.temp.cleanup()

    def test_real_device_arm64_is_accepted(self):
        fixture(self.path)
        report = inspect(self.path, "org.veilgram.buildtwo")
        self.assertEqual("PASS", report["status"])
        self.assertEqual(2, len(report["binaries"]))

    def test_simulator_main_executable_rejected(self):
        fixture(self.path, platform=7)
        self.assertEqual("FAIL", inspect(self.path, "org.veilgram.buildtwo")["status"])

    def test_simulator_extension_rejected(self):
        fixture(self.path, extension_platform=7)
        self.assertEqual("FAIL", inspect(self.path, "org.veilgram.buildtwo")["status"])

    def test_unrelated_extension_id_rejected(self):
        fixture(self.path, extension_id="com.someone.else.Share")
        self.assertEqual("FAIL", inspect(self.path, "org.veilgram.buildtwo")["status"])

    def test_wrong_expected_bundle_rejected(self):
        fixture(self.path)
        self.assertEqual("FAIL", inspect(self.path, "io.example.other")["status"])

    def test_corrupt_zip_rejected(self):
        self.path.write_bytes(b"not-a-zip")
        with self.assertRaises(zipfile.BadZipFile):
            inspect(self.path, "org.veilgram.buildtwo")


if __name__ == "__main__":
    unittest.main()
