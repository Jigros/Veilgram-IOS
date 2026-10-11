#!/usr/bin/env python3
"""Inspect a BUILD-1 simulator IPA without unpacking or executing its contents.

This checks product identity, not code signing, icon originality, launch,
Telegram API compatibility, or whether a device installation will work.
"""
import argparse
import hashlib
import json
import plistlib
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath

EXPECTED_NAME = "Veilgram"
NAME_ENTRY = re.compile(rb'"CFBundleDisplayName"\s*=\s*"([^"\r\n]*)"\s*;')


def inspect(ipa: Path, expected_bundle_id: str) -> dict:
    if not ipa.is_file():
        raise ValueError(f"IPA does not exist: {ipa}")
    if not expected_bundle_id or expected_bundle_id.startswith(
        ("org.example.", "org.telegram.", "ph.telegra.")
    ):
        raise ValueError("Pass the actual independent --bundle-id, not a placeholder or Telegram ID")

    sha = hashlib.sha256()
    with ipa.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            sha.update(chunk)

    problems = []
    extensions = []
    locales = []
    with zipfile.ZipFile(ipa) as archive:
        names = set(archive.namelist())
        app_plists = sorted(
            p for p in names
            if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", p)
        )
        if len(app_plists) != 1:
            raise ValueError(f"Expected exactly one Payload/*.app/Info.plist, found {len(app_plists)}")
        root = app_plists[0].rsplit("/", 1)[0] + "/"
        app_info = plistlib.loads(archive.read(app_plists[0]))
        bundle_id = str(app_info.get("CFBundleIdentifier", ""))
        display = str(app_info.get("CFBundleDisplayName", ""))
        bundle_name = str(app_info.get("CFBundleName", ""))
        if bundle_id != expected_bundle_id:
            problems.append(f"App bundle ID: {bundle_id!r} != {expected_bundle_id!r}")
        if display != EXPECTED_NAME:
            problems.append(f"App display name: {display!r} != {EXPECTED_NAME!r}")
        if bundle_name != EXPECTED_NAME:
            problems.append(f"App bundle name: {bundle_name!r} != {EXPECTED_NAME!r}")

        for path in sorted(names):
            if not path.startswith(root):
                continue
            relative = path[len(root):]
            if re.fullmatch(r"[^/]+\.lproj/InfoPlist\.strings", relative):
                raw = archive.read(path)
                for encoding in ("utf-8", "utf-16", "utf-16-le"):
                    try:
                        decoded = raw.decode(encoding)
                        break
                    except UnicodeDecodeError:
                        continue
                else:
                    problems.append(f"Unreadable localization {relative}")
                    continue
                found = re.findall(r'"CFBundleDisplayName"\s*=\s*"([^"\r\n]+)"\s*;', decoded)
                locale = relative.split("/", 1)[0]
                locales.append(locale)
                if found != [EXPECTED_NAME]:
                    problems.append(f"Localized name {locale}: {found!r}")
            if re.fullmatch(r"PlugIns/[^/]+\.appex/Info\.plist", relative):
                extension_info = plistlib.loads(archive.read(path))
                extension_id = str(extension_info.get("CFBundleIdentifier", ""))
                extension_name = str(extension_info.get("CFBundleName", ""))
                extensions.append({"path": relative, "bundle_id": extension_id, "name": extension_name})
                if not extension_id.startswith(expected_bundle_id + "."):
                    problems.append(f"Extension ID does not belong to app: {relative}: {extension_id}")
                if EXPECTED_NAME not in extension_name:
                    problems.append(f"Extension does not use Veilgram name: {relative}: {extension_name}")
        if not locales:
            problems.append("No localized InfoPlist.strings found inside app")
        if not extensions:
            problems.append("No embedded app extensions found; verify expected BUILD target")

    return {
        "ipa": ipa.name,
        "sha256": sha.hexdigest(),
        "bundle_id": bundle_id,
        "display_name": display,
        "bundle_name": bundle_name,
        "localized_resources": locales,
        "extensions": extensions,
        "problems": problems,
        "status": "PASS" if not problems else "FAIL",
        "scope": "IPA structure and identity only; not an iOS execution or signing test",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path, help="Locally built simulator .ipa")
    parser.add_argument("--bundle-id", required=True, help="Expected independent app bundle ID")
    parser.add_argument("--report", type=Path, help="Optional JSON report destination")
    args = parser.parse_args()
    try:
        result = inspect(args.ipa, args.bundle_id)
    except (ValueError, OSError, zipfile.BadZipFile, plistlib.InvalidFileException) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 2
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    print(output, end="")
    if args.report:
        args.report.write_text(output, encoding="utf-8")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
