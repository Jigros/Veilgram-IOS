# Veilgram artwork replacement inventory (2026-09-30)

**Status: NOT REPLACED.** BUILD-1/BUILD-2 compile checks do not satisfy Telegram's third-party logo requirements. Do not publish an installable Veilgram release showing official Telegram logos.

## Primary app icons

- `Telegram/BUILD` `composer_icon_folders = ["Telegram"]` and `app_icons = [":{}_icon"...]` select `Telegram/Telegram-iOS/Telegram.alticon` as the bundled primary icon. Replacing only `DefaultAppIcon.xcassets` is insufficient.
- `alternate_icon_folders` includes `BlackIcon`, `BlackClassicIcon`, `BlackFilledIcon`, `BlueIcon`, `BlueClassicIcon`, `BlueFilledIcon`, `WhiteFilledIcon`, `New1`, `New2`, `Premium`, `PremiumBlack`, `PremiumTurbo`; all 12 need original Veilgram artwork or need to be removed from the shipping list with a UI fallback and tested.
- `Telegram/Telegram-iOS/AppIcons.xcassets` currently contains `BlueFilledIcon.appiconset`, `BlackIcon.appiconset`, `BlackFilledIcon.appiconset`, `BlueIcon.appiconset`; `DefaultAppIcon.xcassets/AppIconLLC.appiconset` is also present.
- A local inventory counted 159 PNG files whose paths include `alticon`, `AppIcon` or `DefaultAppIcon`, not counting all branding imagery, vector assets or xcassets catalog metadata.

## Additional app surfaces to inspect

- `Telegram/Telegram-iOS/Icons.xcassets/Shortcuts/AppIcon.imageset`.
- `Telegram/Watch/App/Assets.xcassets/AppIcon.appiconset`.
- `Telegram/WatchApp/tgwatch Watch App/Assets.xcassets/AppIcon.appiconset`.
- `submodules/PremiumUI/Sources/AppIconsDemoComponent.swift`: previews/upsell icon imagery.
- `submodules/SettingsUI/Sources/Themes/ThemeSettingsAppIconItem.swift`: icon switching UI.
- `Telegram/Telegram-iOS`: splash, onboarding, app-settings previews and extension resources require visual inspection for Telegram mark or wordmark, beyond simple filename checks.

## Acceptance

- [ ] Select/create a standalone Veilgram visual identity, check originality and rights; prefer vector master exported to Apple-required scales with deterministic scripts.
- [ ] Replace every active app icon/alternate icon and in-app depiction. Remove unused inherited icon variants rather than leaving confusing Telegram branding in a menu.
- [ ] Inspect assembled device IPA app/extension icon assets and alternate icon Info.plist names, not just repo files.
- [ ] Check light/dark/tinted iOS icon variants, icons in Settings and share sheet, Watch/extension packaging as applicable.
- [ ] Run full BUILD-2 and device screenshot review and verify no official Telegram logo appears in user-visible brand surfaces.
- [ ] Keep trademark attribution separate from source-code copyright/license notices. Never delete Telegram copyright or third-party license notices as a branding shortcut.

This inventory is a release-blocker checklist, not a claim of completed icon replacement.

## Verified assembled BUILD-2 evidence (2026-10-01)

Independently downloaded successful [BUILD-2 run 36714922763](https://github.com/Jigros/Veilgram-IOS/actions/runs/36714922763) on NixOS. IPA SHA256 `a42a46b754ca822e7fc2a1dee79b6d7f19e5078fdf9ec3691414a676244a11c1` and ARM64 iOS Mach-O platform verification PASS (host + six extensions).

Inspected actual `Payload/Telegram.app/Info.plist` rather than just repository source:

- `CFBundleIdentifier` = `org.veilgram.buildtwo` and `CFBundleDisplayName` = `Veilgram`.
- `CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName` = **`Telegram`** with `CFBundleIconFiles = ["Telegram60x60"]`; official Telegram icon is still referenced as main icon.
- 12 alternate icon IDs remain: `BlueIcon`, `Premium`, `BlackIcon`, `PremiumTurbo`, `WhiteFilledIcon`, `BlackFilledIcon`, `BlueClassicIcon`, `New1`, `New2`, `BlackClassicIcon`, `BlueFilledIcon`, `PremiumBlack`.
- Six packaged extensions and five `Assets.car` files are present; all icon/brand asset catalogs need visual review before a release.
- Compressed IPA is about 535 MiB; shipping size should be audited once compilation is stable.

**Release gate FAILED: official primary icon and alternate icon identifiers persist in packaged IPA.** Merely setting app name and bundle ID is not sufficient.
