#!/usr/bin/env python3
from pathlib import Path
import re

build = Path("Telegram/BUILD").read_text(encoding="utf-8")
app_delegate = Path("submodules/TelegramUI/Sources/AppDelegate.swift").read_text(encoding="utf-8")

m = re.search(r"alternate_icon_folders\s*=\s*\[(.*?)\]", build, re.S)
assert m is not None, "alternate_icon_folders assignment missing"
start = app_delegate.index("}, getAvailableAlternateIcons: {")
end = app_delegate.index("}, getAlternateIconName: {", start)
binding = app_delegate[start:end]
inherited = [
    "BlackIcon", "BlackClassicIcon", "BlackFilledIcon", "BlueIcon",
    "BlueClassicIcon", "BlueFilledIcon", "WhiteFilledIcon", "New1", "New2",
    "Premium", "PremiumBlack", "PremiumTurbo",
]
folders = m.group(1)
for name in inherited:
    assert name not in folders, f"inherited icon {name} still packaged"
    assert name not in binding, f"inherited icon {name} still exposed in application bindings"

print("PASS: inherited Telegram alternate app icons are absent; Veilgram-owned variants are allowed")

assert "Telegram iOS Color Theme File" not in build, "user-visible Telegram theme-file description remains"
assert "<string>BlueIcon@3x.png</string>" not in build, "Telegram theme-file icon remains"
assert "<string>Veilgram Theme File</string>" in build, "Veilgram theme-file description missing"