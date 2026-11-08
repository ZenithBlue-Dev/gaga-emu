# App Store Metadata Draft

Draft listing for GagaEmu, en-US. The upload copy is `AppStore/metadata/en-US/*.txt`, which `scripts/appstore_metadata.py` reads. That copy holds the same text as this draft, so change both. Check it with `scripts/appstore_metadata.py --check` (no network). Nothing here has been uploaded or submitted.

Voice and legal rules are in `docs/BRAND.md`. Every feature claimed below exists in `Sources/`. The listing does not name Manic EMU or any console maker, and it does not copy Manic EMU's wording.

## Owner decisions

| Field | Status |
|---|---|
| Price | TODO-owner. `AppStore/app.json` says "Owner's choice". |
| Paywall (Gaga Plus) | TODO-owner. Plans, prices and whether Gaga Plus is listed at all. The draft does not mention Gaga Plus, so the listing sells only the free app. If Gaga Plus ships, add a short, factual section from `Sources/UI/Settings/GagaPlusView.swift` and never a price. |
| App Store ID | TODO-owner. Assigned by App Store Connect. Then set `SiteLinks.appStore` in `Sources/App/AppState.swift` to `https://apps.apple.com/app/id<ID>`. |
| Trademark check on "GagaEmu" | TODO-owner, from `docs/BRAND.md`. |

## Name

`GagaEmu - Game Emulator` (23 of 30)

The earlier `GagaEmu - Retro Game Emulator` was dropped as generic emulator-listing phrasing.

## Subtitle

`A quiet shelf for your games` (28 of 30)

Replaces `All-in-One Classic Console Emu`, which read like Manic EMU's "all-in-one" positioning and promised more than the app does today (`docs/BRAND.md`).

## Promotional text

Play homebrew and the backups you own, upright or in landscape, with touch controls or a game controller. GagaEmu comes with no games, ROMs or BIOS.

## Description

GagaEmu is a quiet shelf for games you already own. It plays homebrew and backups of your own cartridges and discs, on iPhone and iPad, upright or in landscape.

You provide every game and every BIOS file yourself, and they must be legally obtained. GagaEmu does not include any games, ROMs or BIOS, and it does not sell, link to or help you obtain them.

YOUR SHELF
- Your games sit on shelves by system, with search and filter chips.
- Continue keeps the last game you played one tap away.
- Cover art is optional and off by default.

ADDING FILES
- Choose from Files, or drop files onto the Add screen.
- WiFi Transfer sends files from a browser on your network. It is off by default, and its traffic is unencrypted.
- Zip archives are unpacked on import.
- Multi-Disc Helper joins disc files into one playlist.
- Patch a ROM applies an IPS, UPS or BPS patch to a copy. The original is left untouched.

PLAYING
- Touch controls, or a game controller supported by iOS.
- Save states and fast forward from the pause menu. Rewind where the system supports it.
- Picture filters, from Original to CRT.
- Custom skins for the touch controls.

EARLY RELEASE
GagaEmu is in early development. Speed depends on your device and the software you load. We make no promise that any particular title will run.

PRIVACY
GagaEmu has no accounts, analytics, advertising or tracking. Your games and saves stay on your device unless you share a file. With Cover Art turned on, game titles are sent to a cover art service to find box art.

GagaEmu is an independent project. It is not affiliated with, endorsed by or sponsored by any console maker. All trademarks belong to their owners.

### Where each claim lives

| Claim | Source |
|---|---|
| Shelves, search, chips, Continue | `Sources/UI/Games/LibraryView.swift` |
| Cover Art, off by default | `Sources/UI/Settings/SettingsView.swift`, `AppStore/app.json` |
| Files, drop, WiFi Transfer, Multi-Disc Helper, Patch a ROM | `Sources/UI/Import/AddView.swift` |
| Zip unpacking | `CoreCatalog.unpackArchive` in `Sources/App/AppState.swift` |
| Controllers | `Sources/Input/ControllerManager.swift` |
| Save states, fast forward, rewind status | `Sources/UI/Game/GameView.swift`, `Sources/Session/GameSession.swift` |
| Filters Original to CRT | `Shader.builtIn` in `Sources/App/AppState.swift` (free ones only) |
| Skins | `Sources/UI/Settings/AssignSkinView.swift`, `SkinEditorView.swift` |
| Upright and landscape on iPhone and iPad | `Sources/App/Info.plist` |

## Keywords

`homebrew,retro,classic,controller,gamepad,save states,rewind,landscape,crt filter,rom patch` (91 of 100)

No console maker or product names, and no word from the name.

## URLs

From `SiteLinks` in `Sources/App/AppState.swift`:

- Support: https://zenithblue-oss.github.io/gaga-emu-site/support.html
- Privacy: https://zenithblue-oss.github.io/gaga-emu-site/privacy.html

## Age rating notes

`AppStore/app.json` answers every content question with NONE or false. Expected result: the lowest rating. The owner confirms it in App Store Connect.

- The app ships no games. Content a user loads is not part of the app and is not rated by these answers.
- WiFi Transfer is a local file server, off by default. It is not unrestricted web access.
- No user-generated content, messaging, advertising, gambling or loot boxes.

## Screenshots

`scripts/make_screenshots.swift` composes them from `design/store/captions.json` and the captures in `design/store/captures/`. It writes to `build/store/` by default, one folder per display class: `iphone-6.9` (2868 x 1320), `iphone-6.3` (2622 x 1206) and `ipad-13` (2752 x 2064; Apple requires 13" iPad screenshots because the app runs on iPad, read 2026-11-08 on App Store Connect Help, Screenshot specifications). The iPad set uses the same captions and captures. Placeholders in `design/store/placeholders/` stand in until real device captures exist. Do not upload the placeholder set. `scripts/check_store_assets.py` fails if a Manic EMU asset path returns to the pipeline.
