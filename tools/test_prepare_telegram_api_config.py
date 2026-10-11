#!/usr/bin/env python3
"""Offline, secret-free tests for Veilgram's API credential configuration."""
import contextlib
import io
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

import prepare_telegram_api_config as auth

FAKE_HASH = "a1" * 16  # tests only; never an official or user credential


class CredentialConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="veilgram-auth-tests-")
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.template = self.dir / "template.json"
        self.template.write_text(json.dumps({
            "bundle_id": "placeholder",
            "api_id": "placeholder",
            "api_hash": "placeholder",
            "team_id": "placeholder",
            "app_specific_url_scheme": "tg",
            "enable_siri": False,
            "enable_icloud": False,
            "app_center_id": "0",
        }), encoding="utf-8")
        self.patch = patch.object(auth, "TEMPLATE", self.template)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        # Temporary test files must not appear inside the simulated repository.
        self.project_root = self.dir / "checkout"
        self.project_root.mkdir()
        self.root_patch = patch.object(auth, "REPO_ROOT", self.project_root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)

    def credentials(self, content=None, filename="API_KEYS"):
        file = self.dir / filename
        file.write_text(
            content if content is not None else f"APP_ID=1234567\nAPP_HASH={FAKE_HASH}\n",
            encoding="utf-8"
        )
        file.chmod(0o600)
        return file

    def config(self, source="external", credentials=None):
        return auth.build_configuration(
            source, credentials, "org.veilgram.beta",
            "ABCDEFGHIJ", "veilgram-beta"
        )

    def test_fixture_has_no_real_credentials(self):
        c = self.config("fixture")
        self.assertEqual(c["api_id"], "1")
        self.assertEqual(c["api_hash"], "0" * 32)

    def test_external_ayugram_style_api_keys(self):
        c = self.config(credentials=self.credentials())
        self.assertEqual(c["api_id"], "1234567")
        self.assertEqual(c["api_hash"], FAKE_HASH)
        self.assertEqual(c["bundle_id"], "org.veilgram.beta")
        self.assertFalse(c["enable_icloud"])

    def test_external_json_aliases(self):
        c = self.config(credentials=self.credentials(
            json.dumps({"api_id": 1234567, "api_hash": FAKE_HASH}),
            "private.json"
        ))
        self.assertEqual(c["api_hash"], FAKE_HASH)

    def test_missing_credentials_rejected(self):
        with self.assertRaises(auth.ConfigurationError):
            self.config(credentials=None)

    def test_does_not_mix_fixture_with_external(self):
        with self.assertRaises(auth.ConfigurationError):
            self.config("fixture", self.credentials())

    def test_empty_or_placeholder_values_rejected(self):
        for value in ("", "0" * 32, "X" * 32):
            with self.subTest(value=value):
                with self.assertRaises(auth.ConfigurationError):
                    self.config(credentials=self.credentials(f"APP_ID=42\nAPP_HASH={value}\n"))

    def test_forbid_unrelated_signing_secrets(self):
        with self.assertRaises(auth.ConfigurationError):
            self.config(credentials=self.credentials(
                f"APP_ID=42\nAPP_HASH={FAKE_HASH}\nSIGNING_KEY_PASSWORD=secret\n"
            ))

    def test_duplicate_or_conflicting_fields_rejected(self):
        for text in (
            f"APP_ID=42\nAPP_ID=42\nAPP_HASH={FAKE_HASH}\n",
            f"APP_ID=42\nAPI_ID=43\nAPP_HASH={FAKE_HASH}\n",
        ):
            with self.subTest(text=text):
                with self.assertRaises(auth.ConfigurationError):
                    self.config(credentials=self.credentials(text))

    def test_world_readable_credentials_rejected(self):
        c = self.credentials()
        c.chmod(0o644)
        with self.assertRaises(auth.ConfigurationError):
            self.config(credentials=c)

    def test_wrong_bundle_id_rejected(self):
        with self.assertRaises(auth.ConfigurationError):
            auth.build_configuration(
                "fixture", None, "ph.telegra.Telegraph", "ABCDEFGHIJ", "veilgram-local"
            )

    def test_file_mode_and_hash_never_printed(self):
        target = self.dir / "generated" / "build.json"
        cfg = self.config(credentials=self.credentials())
        capture = io.StringIO()
        with contextlib.redirect_stdout(capture):
            output = auth.save_configuration(target, cfg)
        self.assertEqual(output, target.resolve())
        self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o600)
        self.assertEqual(json.loads(output.read_text())["api_hash"], FAKE_HASH)
        self.assertNotIn(FAKE_HASH, capture.getvalue())


if __name__ == "__main__":
    unittest.main()
