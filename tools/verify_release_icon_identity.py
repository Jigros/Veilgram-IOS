#!/usr/bin/env python3
"""Release-only guard against publishing Veilgram with Telegram-branded app icons.

This examines actual IPA Info.plist metadata, not source names. Never removes
copyright notices, license attributions or inherited implementation filenames.
"""
import argparse
import json
from pathlib import Path
import plistlib
import re
import sys
import zipfile


def release_icon_findings(ipa: Path) -> list[str]:
    with zipfile.ZipFile(ipa) as archive:
        candidates = [
            name for name in archive.namelist()
            if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)
        ]
        if len(candidates) != 1:
            return ["Expected exactly one top-level iOS .app Info.plist"]
        info = plistlib.loads(archive.read(candidates[0]))
        findings: list[str] = []

        if info.get("CFBundleDisplayName") != "Veilgram":
            findings.append("Primary app CFBundleDisplayName is not Veilgram")
        bundle = info.get("CFBundleIdentifier", "")
        if not bundle.startswith("org.veilgram."):
            findings.append("Unexpected non-Veilgram bundle identifier")

        icon_tables = [
            (key, value) for key, value in info.items()
            if key == "CFBundleIcons" or key.startswith("CFBundleIcons~")
        ]
        if not icon_tables:
            findings.append("No CFBundleIcons metadata available to inspect")
        imported_types = info.get("UTImportedTypeDeclarations", [])
        if isinstance(imported_types, list):
            for index, declaration in enumerate(imported_types):
                if not isinstance(declaration, dict):
                    continue
                description = declaration.get("UTTypeDescription", "")
                if isinstance(description, str) and "telegram" in description.lower():
                    findings.append(
                        f"UTImportedTypeDeclarations[{index}]: user-visible Telegram description {description!r}"
                    )
                icon_files = declaration.get("UTTypeIconFiles", [])
                if isinstance(icon_files, list):
                    for icon_file in icon_files:
                        if isinstance(icon_file, str) and (
                            "telegram" in icon_file.lower()
                            or icon_file in {"BlueIcon@3x.png", "BlueIcon.png"}
                        ):
                            findings.append(
                                f"UTImportedTypeDeclarations[{index}]: inherited Telegram file icon {icon_file!r}"
                            )

        for name, group in icon_tables:
            primary = group.get("CFBundlePrimaryIcon", {})
            alternate = group.get("CFBundleAlternateIcons", {})
            if not primary:
                findings.append(f"{name}: no primary icon")
            for item in [primary, *alternate.values()]:
                allnames = [
                    item.get("CFBundleIconName", ""),
                    *(item.get("CFBundleIconFiles") or []),
                ]
                for icon_name in allnames:
                    if "telegram" in icon_name.lower():
                        findings.append(
                            f"{name}: official Telegram icon reference {icon_name!r}"
                        )
            # Block well-known inherited alternate icon IDs until fully
            # replaced/removed and explicitly verified by a designer.
            inherited = {
                "BlueIcon", "Premium", "BlackIcon", "PremiumTurbo",
                "WhiteFilledIcon", "BlackFilledIcon", "BlueClassicIcon",
                "New1", "New2", "BlackClassicIcon", "BlueFilledIcon",
                "PremiumBlack",
            }
            remaining = set(alternate) & inherited
            if remaining:
                findings.append(
                    f"{name}: inherited alternate icon IDs: {', '.join(sorted(remaining))}"
                )
        return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--json-report", type=Path)
    args = parser.parse_args()
    try:
        findings = release_icon_findings(args.ipa)
    except (OSError, zipfile.BadZipFile, plistlib.InvalidFileException) as exc:
        findings = [f"Cannot inspect IPA: {type(exc).__name__}"]
    report = {
        "status": "FAIL" if findings else "PASS",
        "release_blockers": findings,
        "scope": "Info.plist app icon identifiers plus user-visible imported-type description/icon metadata; does not visually scan Assets.car or screenshots",
    }
    if args.json_report:
        args.json_report.write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
