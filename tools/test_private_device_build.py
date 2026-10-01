#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest
from unittest import mock

MODULE_PATH = Path(__file__).with_name("private_device_build.py")
SPEC = importlib.util.spec_from_file_location("private_device_build", MODULE_PATH)
assert SPEC and SPEC.loader
private_build = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(private_build)


class PrivateDeviceBuildTests(unittest.TestCase):
    def test_require_private_accepts_ignored_root(self):
        path = private_build.PRIVATE_ROOT / "API_KEYS"
        self.assertEqual(
            private_build.require_private(path, "Credentials"),
            path.resolve(),
        )

    def test_require_private_rejects_repo_or_external_path(self):
        with self.assertRaises(SystemExit):
            private_build.require_private(
                private_build.REPO_ROOT / "API_KEYS",
                "Credentials",
            )
        with self.assertRaises(SystemExit):
            private_build.require_private(
                Path.home() / "API_KEYS",
                "Credentials",
            )

    def test_dirty_tracked_checkout_is_rejected(self):
        root = str(private_build.REPO_ROOT.resolve())
        with mock.patch.object(
            private_build,
            "output",
            side_effect=[root, " M Telegram/BUILD"],
        ):
            with self.assertRaises(SystemExit):
                private_build.validate_repo_state()

    def test_clean_checkout_returns_source_sha(self):
        root = str(private_build.REPO_ROOT.resolve())
        expected = "a" * 40
        with mock.patch.object(
            private_build,
            "output",
            side_effect=[root, "", expected],
        ):
            self.assertEqual(private_build.validate_repo_state(), expected)

    def test_non_macos_build_is_rejected(self):
        with mock.patch.object(private_build.platform, "system", return_value="Linux"):
            with self.assertRaises(SystemExit):
                private_build.validate_macos_toolchain()

    def test_pinned_macos_toolchain_passes(self):
        def fake_output(args):
            if args[:2] == ["sw_vers", "-productVersion"]:
                return "26.0"
            if args[:2] == ["xcodebuild", "-version"]:
                return "Xcode 26.2\nBuild version 17C52"
            if args[-1] == "--version":
                return "bazel 8.4.2"
            raise AssertionError(args)

        with (
            mock.patch.object(private_build.platform, "system", return_value="Darwin"),
            mock.patch.object(private_build, "output", side_effect=fake_output),
            mock.patch.object(private_build.shutil, "which", return_value="/usr/local/bin/bazel"),
        ):
            private_build.validate_macos_toolchain()

    def test_wrong_bazel_version_is_rejected(self):
        def fake_output(args):
            if args[:2] == ["sw_vers", "-productVersion"]:
                return "26.0"
            if args[:2] == ["xcodebuild", "-version"]:
                return "Xcode 26.2\nBuild version 17C52"
            if args[-1] == "--version":
                return "bazel 8.5.0"
            raise AssertionError(args)

        with (
            mock.patch.object(private_build.platform, "system", return_value="Darwin"),
            mock.patch.object(private_build, "output", side_effect=fake_output),
            mock.patch.object(private_build.shutil, "which", return_value="/usr/local/bin/bazel"),
        ):
            with self.assertRaises(SystemExit):
                private_build.validate_macos_toolchain()


if __name__ == "__main__":
    unittest.main()
