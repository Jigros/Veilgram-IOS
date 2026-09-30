#!/usr/bin/env python3
"""Generate non-Apple-valid, compile-only profiles from public upstream fixtures.

NEVER use these for installation, production signing, or distribution.
The PEM extracted from the upstream PUBLIC test P12 is ephemeral.
"""
import argparse
import os
import plistlib
import subprocess
import tempfile
from pathlib import Path


def run(args):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


def generate(template_dir, p12, destination, bundle_id, team_id):
    if not bundle_id.startswith("org.veilgram.") or not team_id.isalnum():
        raise ValueError("Expected distinct org.veilgram.* test bundle ID and alphanumeric fixture team")
    if not template_dir.is_dir() or not p12.is_file():
        raise ValueError("Missing upstream fixture files")
    destination.mkdir(parents=True, exist_ok=True)
    templates = sorted(template_dir.glob("*.mobileprovision"))
    if len(templates) < 6:
        raise ValueError("Incomplete upstream fixture profile set")
    with tempfile.TemporaryDirectory(prefix="veilgram-test-profiles-") as folder:
        key = Path(folder) / "fixture-key-and-cert.pem"
        key.write_bytes(run(["openssl", "pkcs12", "-in", str(p12), "-passin", "pass:",
                             "-nodes", "-legacy"]))
        key.chmod(0o600)
        cert = run(["openssl", "x509", "-in", str(key), "-outform", "DER"])
        for original in templates:
            data = plistlib.loads(run(["openssl", "cms", "-verify", "-inform", "DER",
                                      "-noverify", "-in", str(original)]))
            original_id = data.get("Entitlements", {}).get("application-identifier", "")
            if "." not in original_id:
                raise ValueError("Missing original fixture application identifier")
            # Only known sample extension names from Telegram's public fixture set.
            postfix = original_id[len(original_id.split(".", 1)[0] + ".ph.telegra.Telegraph"):]
            if original_id != original_id.split(".", 1)[0] + ".ph.telegra.Telegraph" + postfix:
                raise ValueError("Unknown source profile identity")
            ent = data["Entitlements"]
            ent["application-identifier"] = team_id + "." + bundle_id + postfix
            ent["com.apple.developer.team-identifier"] = team_id
            ent["keychain-access-groups"] = [team_id + "." + bundle_id + ".*"]
            if "com.apple.security.application-groups" in ent:
                ent["com.apple.security.application-groups"] = ["group." + bundle_id]
            for name in ("com.apple.developer.icloud-container-identifiers",
                         "com.apple.developer.ubiquity-container-identifiers",
                         "com.apple.developer.icloud-container-development-container-identifiers"):
                ent.pop(name, None)
            ent.pop("com.apple.developer.ubiquity-kvstore-identifier", None)
            data["DeveloperCertificates"] = [cert]
            data["ApplicationIdentifierPrefix"] = [team_id]
            data["TeamIdentifier"] = [team_id]
            data["TeamName"] = "Veilgram compile-only fixture"
            data["Name"] = "Veilgram test " + original.stem
            # Old Apple-signed DER payload, if present, is invalid after changes.
            data.pop("DER-Encoded-Profile", None)
            plain = Path(folder) / ("profile-" + original.stem + ".plist")
            plain.write_bytes(plistlib.dumps(data))
            target = destination / original.name
            run(["openssl", "cms", "-sign", "-binary", "-nodetach", "-in", str(plain),
                 "-outform", "DER", "-signer", str(key), "-inkey", str(key), "-out", str(target)])
            verified = plistlib.loads(run(["openssl", "cms", "-verify", "-inform", "DER",
                                           "-noverify", "-in", str(target)]))
            if verified["Entitlements"]["application-identifier"] != team_id + "." + bundle_id + postfix:
                raise ValueError("Generated profile identifier mismatch")
    print("PASS: generated", len(templates), "PUBLIC-fixture-backed compile-only profiles (NOT Apple valid)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--team-id", default="C67CF9S4VU")
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--template-dir", type=Path, default=Path("build-system/fake-codesigning/profiles"))
    parser.add_argument("--fixture-p12", type=Path, default=Path("build-system/fake-codesigning/certs/SelfSigned.p12"))
    opts = parser.parse_args()
    generate(opts.template_dir, opts.fixture_p12, opts.destination, opts.bundle_id, opts.team_id)
