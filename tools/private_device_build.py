#!/usr/bin/env python3
"""Build and verify a private Veilgram iPhone IPA with external Telegram API credentials.

Public CI must never call this tool with real credentials. Build outputs and reports
stay under the ignored .veilgram-private directory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

REPO_ROOT = Path(__file__).resolve().parents[1]
PRIVATE_ROOT = REPO_ROOT / ".veilgram-private"
DEFAULT_CREDENTIALS = PRIVATE_ROOT / "API_KEYS"
DEFAULT_CONFIG = PRIVATE_ROOT / "veilgram-device-configuration.json"
DEFAULT_ARTIFACTS = PRIVATE_ROOT / "artifacts"
FAKE_TEAM_ID = "C67CF9S4VU"


def run(args: list[str], *, env: dict[str, str] | None = None) -> None:
    subprocess.run(args, cwd=REPO_ROOT, env=env, check=True)


def output(args: list[str]) -> str:
    return subprocess.check_output(args, cwd=REPO_ROOT, text=True).strip()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_private(path: Path, description: str) -> Path:
    resolved = path.expanduser().resolve()
    private = PRIVATE_ROOT.resolve()
    if not resolved.is_relative_to(private):
        raise SystemExit(f"{description} must stay under {private}")
    return resolved


def validate_repo_state() -> str:
    inside = output(["git", "rev-parse", "--show-toplevel"])
    if Path(inside).resolve() != REPO_ROOT.resolve():
        raise SystemExit("Run from the Veilgram repository checkout")
    status = output(["git", "status", "--porcelain"])
    tracked = [line for line in status.splitlines() if ".veilgram-private/" not in line]
    if tracked:
        raise SystemExit("Refusing private build with tracked working-tree changes")
    return output(["git", "rev-parse", "HEAD"])


def prepare_config(credentials: Path, config: Path, bundle_id: str, url_scheme: str) -> None:
    run([
        sys.executable,
        "tools/prepare_telegram_api_config.py",
        "--source", "external",
        "--credentials", str(credentials),
        "--output", str(config),
        "--bundle-id", bundle_id,
        "--team-id", FAKE_TEAM_ID,
        "--url-scheme", url_scheme,
    ])
    os.chmod(config, 0o600)


def validate_macos_toolchain() -> None:
    if platform.system() != "Darwin":
        raise SystemExit("Private iPhone compilation requires macOS; use --preflight-only elsewhere")
    xcode = output(["xcodebuild", "-version"]).splitlines()
    if not xcode or xcode[0] != "Xcode 26.2":
        raise SystemExit(f"Expected Xcode 26.2, got: {xcode[0] if xcode else 'unknown'}")
    bazel = shutil.which("bazel")
    if bazel is None:
        raise SystemExit("bazel is not available in PATH")


def find_openssl3() -> Path:
    brew = shutil.which("brew")
    if brew is None:
        raise SystemExit("Homebrew is required to locate OpenSSL 3")
    prefix = output([brew, "--prefix", "openssl@3"])
    binary = Path(prefix) / "bin" / "openssl"
    if not binary.is_file():
        raise SystemExit("OpenSSL 3 binary not found")
    return binary


def prepare_fake_signing(bundle_id: str) -> tuple[Path, dict[str, str]]:
    openssl = find_openssl3()
    signing = PRIVATE_ROOT / "compile-only-signing"
    certs = signing / "certs"
    profiles = signing / "profiles"
    if signing.exists():
        shutil.rmtree(signing)
    certs.mkdir(parents=True, mode=0o700)
    profiles.mkdir(parents=True, mode=0o700)
    for source in (REPO_ROOT / "build-system/fake-codesigning/certs").iterdir():
        if source.is_file():
            shutil.copy2(source, certs / source.name)
    run([
        sys.executable,
        "tools/generate_compile_only_profiles.py",
        "--bundle-id", bundle_id,
        "--team-id", FAKE_TEAM_ID,
        "--destination", str(profiles),
    ])
    env = os.environ.copy()
    env["PATH"] = f"{openssl.parent}:{env.get('PATH', '')}"
    run([
        sys.executable,
        "build-system/Make/ImportCertificates.py",
        "--path", str(certs),
    ], env=env)
    return signing, env


def locate_ipa() -> Path:
    ipa = REPO_ROOT / "bazel-bin/Telegram/Telegram.ipa"
    if not ipa.is_file() or ipa.stat().st_size == 0:
        raise SystemExit("Build completed without bazel-bin/Telegram/Telegram.ipa")
    return ipa


def verify_private_ipa(source: Path, destination: Path, bundle_id: str, source_sha: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    shutil.copy2(source, destination)
    os.chmod(destination, 0o600)
    platform_report = destination.with_suffix(".platform.json")
    identity_report = destination.with_suffix(".identity.json")
    branding_report = destination.with_suffix(".branding.json")

    run([
        sys.executable, "tools/verify_build1_ipa.py", str(destination),
        "--bundle-id", bundle_id, "--report", str(identity_report),
    ])
    run([
        sys.executable, "tools/verify_device_ipa.py", str(destination),
        "--bundle-id", bundle_id, "--report", str(platform_report),
    ])

    branding_status = subprocess.run([
        sys.executable, "tools/verify_release_icon_identity.py", str(destination),
        "--json-report", str(branding_report),
    ], cwd=REPO_ROOT).returncode

    manifest = {
        "source_sha": source_sha,
        "ipa": destination.name,
        "ipa_sha256": sha256(destination),
        "bundle_id": bundle_id,
        "configuration": "debug_arm64",
        "device_platform_verified": True,
        "release_branding_gate": "PASS" if branding_status == 0 else "BLOCKED",
        "warning": "Compile-only signing. Re-sign the app and every extension before installing on iPhone.",
    }
    manifest_path = destination.with_suffix(".manifest.json")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    os.chmod(manifest_path, 0o600)
    for report in (platform_report, identity_report, branding_report):
        if report.exists():
            os.chmod(report, 0o600)
    print(json.dumps(manifest, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credentials", type=Path, default=DEFAULT_CREDENTIALS)
    parser.add_argument("--bundle-id", default="org.veilgram.local")
    parser.add_argument("--url-scheme", default="veilgram-local")
    parser.add_argument("--build-number", type=int, default=100)
    parser.add_argument("--cache-dir", type=Path, default=Path.home() / "veilgram-private-device-bazel-cache")
    parser.add_argument("--preflight-only", action="store_true")
    args = parser.parse_args()

    credentials = require_private(args.credentials, "Credentials")
    config = require_private(DEFAULT_CONFIG, "Generated configuration")
    PRIVATE_ROOT.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not credentials.is_file():
        raise SystemExit(f"Missing credentials file: {credentials}")
    if os.name == "posix" and credentials.stat().st_mode & 0o077:
        raise SystemExit("Credentials must be chmod 600")

    source_sha = validate_repo_state()
    prepare_config(credentials, config, args.bundle_id, args.url_scheme)
    print(f"Private API configuration validated for source {source_sha}; credential values were not printed.")

    if args.preflight_only:
        print("PRECHECK PASS: external Telegram API configuration is ready for private macOS compilation.")
        return 0

    validate_macos_toolchain()
    signing, env = prepare_fake_signing(args.bundle_id)
    args.cache_dir.expanduser().mkdir(parents=True, exist_ok=True)
    run([
        sys.executable, "-u", "build-system/Make/Make.py",
        f"--cacheDir={args.cache_dir.expanduser()}",
        "build",
        f"--configurationPath={config}",
        f"--codesigningInformationPath={signing}",
        "--configuration=debug_arm64",
        f"--buildNumber={args.build_number}",
    ], env=env)

    short_sha = source_sha[:12]
    destination = DEFAULT_ARTIFACTS / f"veilgram-private-device-{short_sha}.ipa"
    verify_private_ipa(locate_ipa(), destination, args.bundle_id, source_sha)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
