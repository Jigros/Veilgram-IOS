#!/usr/bin/env python3
from pathlib import Path
import re

build = Path("Telegram/BUILD").read_text(encoding="utf-8")
app_delegate = Path("submodules/TelegramUI/Sources/AppDelegate.swift").read_text(encoding="utf-8")

m = re.search(r"alternate_icon_folders\s*=\s*\[(.*?)\]", build, re.S)
assert m is not None, "alternate_icon_folders assignment missing"
assert not m.group(1).strip(), "Telegram alternate icons are still packaged"

start = app_delegate.index("}, getAvailableAlternateIcons: {")
end = app_delegate.index("}, getAlternateIconName: {", start)
binding = app_delegate[start:end]
assert "return []" in binding, "alternate icon UI binding is not disabled"

inherited = [
    "BlackIcon", "BlackClassicIcon", "BlackFilledIcon", "BlueIcon",
    "BlueClassicIcon", "BlueFilledIcon", "WhiteFilledIcon", "New1", "New2",
    "Premium", "PremiumBlack", "PremiumTurbo",
]
for name in inherited:
    assert name not in binding, f"inherited icon {name} still exposed in application bindings"

print("PASS: inherited Telegram alternate app icons are neither packaged nor exposed in Settings")
