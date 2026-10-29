#!/usr/bin/env python3
"""Check that BUILD-1 product branding is consistent across Telegram-iOS resources.

This performs static checks only; it is not a substitute for the real Xcode build.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "Telegram" / "Telegram-iOS"
BRAND = "Veilgram"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    build = (ROOT / "Telegram" / "BUILD").read_text(encoding="utf-8")
    display_fragment = re.compile(
        r"<key>CFBundleDisplayName</key>\s*<string>Veilgram</string>"
    )
    bundle_fragment = re.compile(
        r"<key>CFBundleName</key>\s*<string>Veilgram</string>"
    )
    require(len(display_fragment.findall(build)) == 2,
            "Expected two Veilgram display-name fragments in Telegram/BUILD")
    require(len(bundle_fragment.findall(build)) == 7,
            "Expected seven Veilgram app/extension bundle-name fragments")

    localized = sorted(IOS_ROOT.glob("*.lproj/InfoPlist.strings"))
    require(len(localized) >= 15, "Unexpectedly few localized InfoPlist.strings")
    label = re.compile(r'^\s*"CFBundleDisplayName"\s*=\s*"([^"\n]+)"\s*;', re.M)
    for path in localized:
        matches = label.findall(path.read_text(encoding="utf-8"))
        require(matches == [BRAND],
                f"{path.relative_to(ROOT)} must have exactly one Veilgram label, got {matches!r}")

    template = json.loads(
        (ROOT / "build-system" / "veilgram-development.example.json").read_text(encoding="utf-8")
    )
    require(template.get("bundle_id") == "org.example.Veilgram",
            "Example bundle ID should remain nonproduction")
    require(template.get("app_specific_url_scheme") == "veilgram",
            "Use the independent URL scheme")
    for field in ("api_id", "api_hash"):
        require("{!" in str(template[field]),
                f"{field} must be a placeholder, not a live Telegram credential")
    print(f"PASS: Bazel bundle names, {len(localized)} localized labels, config placeholders")
    print("NOTE: This checks source only; BUILD-1 and device signing remain unverified")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AssertionError, OSError, ValueError, KeyError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
