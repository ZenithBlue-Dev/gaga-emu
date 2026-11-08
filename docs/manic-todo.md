# Manic EMU feature TODO

GagaEmu's UI stays an original design; Manic EMU is a feature reference only, so nothing here asks to copy its layout, labels or art.

Items: 53 open, 39 done (92 total).

The screenshots are gitignored (`maniac-emu-reference-images/walk/`), so the images render only on the owner's Mac.

Source: `docs/manic-gap-analysis.md` (Manic EMU 2.0.2 walk, 2026-11-08) and the screenshots. Priority: P1 highest, P3 lowest. Effort: S (days), M (one to two weeks), L (several weeks or more). Done items come first in each area, open items follow ordered by priority.

## Library

![Games tab, empty](../maniac-emu-reference-images/walk/01-games-empty.png)
![Play history, empty](../maniac-emu-reference-images/walk/09-play-history.png)
![Theme, library display options](../maniac-emu-reference-images/walk/16-settings-theme-2.png)

- [x] Game library grid with platform filter chips and search (`Sources/UI/Games/LibraryView.swift`).
- [x] Play history: Continue panel, Recent filter and per-game play time.
- [x] Games per row, 2 to 5, or Auto (Settings > Display, `Sources/UI/Games/LibraryDisplay.swift`).
- [x] Sort field and sort order, from the Library's filter row and Settings > Display.
- [ ] Cover display: three cover styles, corner radius slider, force square covers, hide game title, hide rating badge. Own design allowed. Built in Settings > Display; Plain style, the slider and hide title still need a device check. (P2, M)
- [ ] Hide scroll indicators toggle. Built; needs a device check. (P3, S)
- [ ] Group title style (abbreviation, full, brand) and hide group title. Built; short code and hide need a device check. (P3, S)
- [ ] Manufacturer filter. GagaEmu filters by platform chip only. (P3, S)
- [ ] Console order. Recorded as not planned in `docs/02` 2.5. (P3, S, blocked: not planned)
- [ ] Reach the controllers panel from the library. Partial: it lives in Settings > Controls only. (P3, S)
- [ ] Community link on the empty library. Deliberate: no Discord or QQ channel. (P3, S, blocked: no community channel)

## Import

![Import tab](../maniac-emu-reference-images/walk/02-import.png)
![Downloads, empty](../maniac-emu-reference-images/walk/03-import-downloads.png)
![More Settings sheet](../maniac-emu-reference-images/walk/04-import-more-settings.png)
![MultiDisc Helper](../maniac-emu-reference-images/walk/06-import-multidisc-helper.png)

- [x] Files import (`Sources/UI/Import/AddView.swift`).
- [x] Wi-Fi transfer through a browser, off by default, session PIN (`Sources/Hub/WiFiTransferServer.swift`).
- [x] Read clipboard import (`Sources/Hub/ClipboardImporter.swift`).
- [x] Drag and drop on Add, Library and game view (`Sources/UI/Import/GameDrop.swift`).
- [x] MultiDisc helper: builds `.m3u` playlists by scanning the ROM folder and grouping by disc naming.
- [ ] Import games from other emulators (five targets in Manic). Value is migrating from emulators covering the same systems. (P3, M, blocked: depends on those apps exposing files)
- [ ] MultiDisc helper: hand-pick discs whose names do not group. (P3, S)
- [ ] Download queue for active transfers. Only useful together with cloud sources or add-by-link. (P3, M)
- [ ] Add game by link. GagaEmu rejects web links on purpose. (P3, M, blocked: App Store rule)

## Cloud and sync

![Add Service](../maniac-emu-reference-images/walk/05-import-add-service.png)
![Settings, Advanced (iCloud Sync row)](../maniac-emu-reference-images/walk/11-settings-2.png)

- [ ] iCloud sync of saves and library across devices. No CloudKit or ubiquity code. (P1, L, blocked: App ID capability)
- [ ] WebDAV as a game source. Needs no vendor account, the cheapest slice. (P2, M)
- [ ] SMB network share as a game source. (P2, M)
- [ ] Google Drive, Dropbox and OneDrive browse and import. Each needs an OAuth client and a file browser. Confirm against App Review 4.7 first. (P2, L, blocked: owner account)
- [ ] RomM server as a game source (self-hosted library). (P3, M)
- [ ] Baidu Cloud and AliCloud browse and import. (P3, L, blocked: owner account)

## Online play

![Online Play Settings](../maniac-emu-reference-images/walk/20-settings-online-play.png)
![Nintendo WFC servers](../maniac-emu-reference-images/walk/21-settings-online-nintendo-wfc.png)
![PSP Networking](../maniac-emu-reference-images/walk/22-settings-online-psp-networking.png)

- [x] Local multiplayer: nearby lockstep with encrypted transport (`Sources/Netplay/`).
- [ ] DS online through replacement WFC servers, with a server choice list and a reset button. Third-party services. (P2, L, blocked: legal review)
- [ ] PSP networking toggle and ad hoc support. No ad hoc code today. (P3, L, blocked: legal review)
- [ ] 3DS Artic Base setup by IP address. Needs core networking and the user's own console. (P3, L, blocked: legal review)
- [ ] 3DS Pretendo Network with an install step for its helper. Third-party service with its own terms. (P3, L, blocked: legal review)
- [ ] Internet netplay beyond local play ("Other Netplay"). Manic's page was not seen. (P3, L, blocked: legal review)

## Achievements

![RetroAchievements sign-in](../maniac-emu-reference-images/walk/23-settings-retroachievements.png)

- [ ] RetroAchievements sign-in and in-game achievements. `rcheevos` appears only in the licence list. (P1, M, blocked: owner account)

## Skins

![Assign Skin](../maniac-emu-reference-images/walk/17-settings-assign-skin.png)

- [x] Assign a skin per platform and orientation, portrait and landscape (`Sources/UI/Settings/AssignSkinView.swift`).
- [x] Skin editor (`Sources/UI/Settings/SkinEditorView.swift`).
- [x] `.deltaskin` support (`Sources/Input/TouchSkinEngine.swift`).
- [x] Skin sound effects toggle.
- [ ] Read `.manicskin` skins. Format must be studied before estimating; compatibility unverified. (P2, M)

## Controllers

![Controllers panel](../maniac-emu-reference-images/walk/08-controllers.png)
![TriggerPro, empty](../maniac-emu-reference-images/walk/24-settings-triggerpro.png)

- [x] Player slots, up to four, for touch and external controllers (`Sources/Input/ControllerManager.swift`).
- [x] Rumble toggle (`Sources/Input/RumbleManager.swift`).
- [x] Auto full screen when a controller connects.
- [x] TriggerPro custom buttons (`Sources/Input/TriggerProManager.swift`). Editor not compared with Manic's, since its list was empty.
- [ ] TriggerPro: compare the editor once Manic's add flow is captured. Partial. (P3, S)

## ROM patcher

![RomPatcher](../maniac-emu-reference-images/walk/07-import-rom-patcher.png)

- [x] IPS, UPS and BPS patching, original left untouched (`Sources/Hub/RomPatcher.swift`).
- [x] PPF 1, 2 and 3 patches; a disc image is patched on disk, not in memory (`Sources/Hub/RomPatcher.swift`).
- [x] APS (GBA and N64) and RUP patches.
- [ ] xdelta patches. Common for disc translations. Most real patches use djw or lzma secondary compression, so a decoder written from RFC 3284 alone would refuse them. (P2, M, blocked: licence check of the implementation)
- [ ] Patch creator mode. Niche. (P3, M)

## Shaders and filters

![Shaders](../maniac-emu-reference-images/walk/26-settings-shaders.png)

- [x] Default presets with live preview (`Sources/UI/Settings/FilterPickerView.swift`).
- [x] Custom parameters, `.metal` and `.slangp` import, saved presets.
- [ ] Browsable RetroArch catalogue. Partial: three community presets against a tab that may be large. (P2, S, blocked: licence per shader)
- [ ] Shader list search. Built; results need a device check. (P3, S)
- [ ] Pick your own image for the preview. (P3, S)
- [ ] GPL shaders (xBRZ, CRT-Royale). Not shipped, replaced by own work. (P3, M, blocked: licence)

## Themes and appearance

![Theme, app icons and colours](../maniac-emu-reference-images/walk/15-settings-theme.png)

- [x] Appearance choice: dark, light or automatic (Settings > Display).
- [ ] Theme colours with a custom colour. Built: swatches pass on the device, the custom colour picker needs a device check. (P3, M)
- [ ] Alternate app icons. No `setAlternateIconName`; needs original icon art. (P3, M)

## Settings

![Settings, General](../maniac-emu-reference-images/walk/11-settings-2.png)
![Settings, Support and Others](../maniac-emu-reference-images/walk/12-settings-3.png)
![Settings, Others and promotions](../maniac-emu-reference-images/walk/13-settings-4.png)
![Settings, About card and version](../maniac-emu-reference-images/walk/14-settings-5.png)
![Cover Scraping toast](../maniac-emu-reference-images/walk/18-settings-cover-scraping.png)

- [x] Membership banner (`Sources/UI/Settings/GagaPlusView.swift`, behind `PaywallGate`).
- [x] Quick Start, opens the most recent game.
- [x] Assign Skin entry.
- [x] Cover scraping, off by default (`Sources/Hub/CoverArtFetcher.swift`). Manic's page was not seen: it only toasted "No compatible games".
- [x] Respect Silent Mode.
- [x] About page and licences (`Sources/UI/Settings/LicencesView.swift`).
- [x] Share the app.
- [x] Clear cache.
- [x] Reset tips.
- [x] Terms and Privacy links.
- [x] Rate card, via the system review prompt.
- [ ] Language selection. Hidden row at `SettingsView.swift:453`; no localisation calls, English only. (P2, M)
- [ ] Auto Save States as a free-standing toggle. Partial: tied to a lock and hidden until the entitlement lands. (P2, S)
- [ ] AirPlay fullscreen. Partial: built in `Sources/UI/Game/ExternalDisplay.swift`, hidden, awaiting a second-screen check. (P2, S)
- [ ] Profile card with nickname, play time and join date. Removed by the redesign (`docs/02` 2.1). Screenshot not embedded, see the end. (P3, S, blocked: not planned)
- [ ] Featured items and sister-app promotion. Deliberate, no player value. (P3, S, blocked: not planned)
- [ ] Discord and QQ links. Deliberate. (P3, S, blocked: no community channel)

## BIOS

![BIOS list](../maniac-emu-reference-images/walk/19-settings-bios.png)

- [x] Required BIOS list with Found or Missing state; import validates name and size (`Sources/App/AppState.swift:1384`).
- [ ] Import button on every BIOS file row. Built; the button shows and the import passes its tests, the file picker needs a device check. (P2, S)
- [ ] Optional files listed per system with Required or Optional labels. Partial: depends on core coverage. (P3, S)

## Emulator cores

![Emulator Core](../maniac-emu-reference-images/walk/27-settings-emulator-core.png)

- [x] Default core per platform, and per-game core picker (`Sources/UI/Games/CorePickerSheet.swift`).
- [ ] Java ME platform. Spike failed (`docs/07` 6.4). (P3, L, blocked: spike failed)

## JIT

![JIT status](../maniac-emu-reference-images/walk/25-settings-jit.png)

- [ ] JIT mode and a sideload build. Dropped by design; do not add a sideload link to the App Store build. (P3, L, blocked: no JIT)

## Help and about

![FAQ](../maniac-emu-reference-images/walk/28-settings-faq.png)
![About](../maniac-emu-reference-images/walk/29-settings-about.png)

- [x] About page with project and legal links.
- [ ] Inline guides inside the app (import, controllers, cheats, skins). Partial: FAQ link and short tips in `Sources/UI/TipLine.swift` only. (P2, S)

## Membership

- [x] Paywall with plans and five feature cards (`Sources/Store/StoreKitManager.swift`, matches `docs/02` 2.6). Screenshot not embedded, see the end.

## Pages not captured yet

The gap analysis could not reach these. Each is a task to capture.

- [ ] Capture game detail and the long-press menu on a populated library. (P2, S, blocked: needs an imported game)
- [ ] Capture the in-game menu, including skin and speed options. (P2, S, blocked: needs an imported game)
- [ ] Capture save states. (P2, S, blocked: needs an imported game)
- [ ] Capture cheats. (P2, S, blocked: needs an imported game)
- [ ] Capture 3DS Pretendo Network. Opening it raised the iOS Local Network prompt. (P3, S, blocked: Local Network prompt)
- [ ] Capture Other Netplay. (P3, S)
- [ ] Capture the Shaders RetroArch tab. (P3, S)
- [ ] Capture Language. (P3, S)
- [ ] Capture Terms of Service. (P3, S)

## Screenshots not embedded

- `10-settings-1.png`: shows the profile card with the nickname and join date, which is personal info.
- `30-paywall.png`: background shows cover art with game titles.
