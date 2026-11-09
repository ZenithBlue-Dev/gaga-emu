# Manic EMU page-by-page gap analysis

Walked Manic EMU 2.0.2 (`com.aoshuang.manicemu`, App Store install) on the owner's iPhone 17, iOS 27.2, on 2026-11-08. The walk was observe-only: no setting changed, nothing imported, no account touched, no purchase started.

Manic is a feature reference only. GagaEmu's UI stays an original design, so nothing here proposes copying Manic's layout, labels or art.

Screenshots live in `maniac-emu-reference-images/walk/`, which is gitignored, so the links below only resolve in a working copy that has them. GagaEmu line numbers are from commit `f0818b5` and can drift.

**Status:** Missing, Partial, Present. **Effort:** S (days), M (one to two weeks), L (several weeks or more). **Blocked** marks an App Store, licence, account or capability limit.

Manic's library was empty, so everything that needs a game was not reachable. See [Pages not reached](#pages-not-reached).

## Summary, ranked by value to the player

| # | Gap | Status | Effort | Blocked? | Page |
| :-- | :--- | :--- | :-- | :--- | :--- |
| 1 | Cross-device save and library sync through iCloud | Missing | L | Yes: needs the iCloud capability on the App ID | [Settings, Advanced](#settings-general-and-advanced) |
| 2 | Connect cloud drives and network shares as game sources (Google Drive, Dropbox, OneDrive, Baidu, AliCloud, WebDAV, SMB, RomM) | Missing | L | Partly: OAuth client registration per provider; see the 4.7 note | [Add Service](#add-service) |
| 3 | RetroAchievements sign-in and achievements | Missing | M | Yes: owner account and approval (`docs/02` 2.7) | [RetroAchievements](#retroachievements) |
| 4 | Internet play services: DS Wi-Fi Connection servers, PSP networking, 3DS Artic Base and Pretendo | Missing | L | Partly: third-party services and terms; review needed | [Online Play](#online-play-settings) |
| 5 | Library display controls: games per row, cover style and corner radius, square covers, hide title, group title style, sort field and order, manufacturer filter, console order | Missing | M | No | [Theme](#theme) |
| 6 | Appearance choice (dark, light, automatic), theme colours, alternate app icons | Missing | M | No, but `docs/02` 2.7 marks them not planned | [Theme](#theme) |
| 7 | Read Manic-format skins (`.manicskin`) | Missing | M | Format compatibility unverified | [Assign Skin](#assign-skin) |
| 8 | ROM patcher: APS, RUP, PPF, xdelta formats and a patch creator mode | Partial | M | Check licence of any xdelta code | [RomPatcher](#rompatcher) |
| 9 | Language selection (localisation) | Missing | M | No | [Settings, Others](#settings-support-others-and-promotions) |
| 10 | Shader list search and a browsable large RetroArch catalogue | Partial | S | Licences per shader | [Shaders](#shaders) |
| 11 | Per-file BIOS slots with direct import and Required or Optional labels for every system | Partial | S | No; owner supplies BIOS | [BIOS](#bios) |
| 12 | Migration import from other emulators | Missing | M | Depends on those apps exposing files | [More Settings](#more-settings-sheet) |
| 13 | Add a game by link, with a download queue | Missing | M | Yes: App Review 4.7 concern; GagaEmu rejects web links today | [More Settings](#more-settings-sheet), [Downloads](#downloads) |
| 14 | Auto save state as a free-standing toggle | Partial | S | No | [Settings, General](#settings-general-and-advanced) |
| 15 | Inline help and guides inside the app | Partial | S | No | [FAQ](#faq) |
| 16 | Java ME platform | Missing | L | Spike failed (`docs/07` 6.4) | [Emulator Core](#emulator-core) |
| 17 | JIT mode and sideload build | Missing | L | Yes: no JIT on the App Store, dropped by design | [JIT](#jit) |

## Games tab

![Games tab](../maniac-emu-reference-images/walk/01-games-empty.png)

**Offers:** game grid (empty here), a controllers button, a play history button, a legal notice and a community link.

**GagaEmu:** library with Continue panel, platform filter chips, Recent filter and search, in `Sources/UI/Games/LibraryView.swift:179` and `:193`; favourites at `:393`.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Library grid | Present | Own shelf design |
| Search | Present | `LibraryView.swift:193`. Manic shows no search on its empty header |
| Display controls | Missing | See [Theme](#theme) |
| Community link | Missing | Deliberate: GagaEmu has no Discord or QQ channel (`docs/02` 2.1) |

## Import tab

![Import tab](../maniac-emu-reference-images/walk/02-import.png)

**Offers:** Files, Wi-Fi transfer through a browser, read clipboard, multi-disc helper, ROM patcher, drag and drop, plus top-bar entries for add service, downloads, help and more settings.

**GagaEmu:** `Sources/UI/Import/AddView.swift`, `Sources/UI/Import/GameDrop.swift`, `Sources/Hub/WiFiTransferServer.swift`, `Sources/Hub/ClipboardImporter.swift`.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Files import | Present | `AddView.swift` |
| Wi-Fi transfer | Present | `WiFiTransferServer.swift`, off by default, session PIN |
| Clipboard import | Present | `ClipboardImporter.swift`. Not opened in Manic because it triggers an iOS paste prompt |
| Drag and drop | Present | `GameDrop.swift`, on Add, Library and game view (`docs/02` 2.4) |
| Multi-disc | Present | See below |
| ROM patcher | Partial | See below |
| Cloud sources | Missing | See below |

### Add Service

![Add Service](../maniac-emu-reference-images/walk/05-import-add-service.png)

**Offers:** browse and import from cloud accounts (Google Drive, Dropbox, OneDrive, Baidu Cloud, AliCloud) and local network services (WebDAV, SMB, RomM).

**GagaEmu:** none. No WebDAV, SMB, RomM or drive code under `Sources/`.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Cloud drive browse and import | Missing | Each provider needs an OAuth client and a file browser. No rows were opened: each starts a sign-in |
| WebDAV, SMB | Missing | No account with a vendor needed, so the cheapest slice of this gap |
| RomM server | Missing | Self-hosted library source |

Pulling a user's own files from their own storage is a different case from an in-app ROM catalogue, but confirm against App Review 4.7 before starting.

### Downloads

![Downloads](../maniac-emu-reference-images/walk/03-import-downloads.png)

**Offers:** a list of active transfers, empty here.

**GagaEmu:** none needed today, because GagaEmu has no remote transfers. Import progress and cancel exist at `AddView.swift:183` and `:186`.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Download queue | Missing | Only useful together with gap 2 or 13 |

### More Settings sheet

![More Settings](../maniac-emu-reference-images/walk/04-import-more-settings.png)

**Offers:** add a game by link, and import games from five other iOS emulators (MeloNX, XeniOS, DukeX, ARMSX2, MeloCafe). No row was opened.

**GagaEmu:** none. `ClipboardImporter.swift` rejects web links on purpose (`docs/02` 2.4).

| Item | Status | Detail |
| :--- | :--- | :--- |
| Add game by link | Missing, Blocked | App Review 4.7 risk. GagaEmu chose not to download ROMs |
| Import from other emulators | Missing | Manic's targets lean towards JIT-era systems. For GagaEmu, value is in migrating from emulators covering the same systems |

### MultiDisc Helper

![MultiDisc Helper](../maniac-emu-reference-images/walk/06-import-multidisc-helper.png)

**Offers:** builds `.m3u` playlists from disc images (`.cue`/`.bin`, `.gdi`, `.chd`, `.cdi`, `.iso`, `.rvz`, `.d64`) picked by hand.

**GagaEmu:** `Sources/Hub/MultiDiscHelper.swift`, `Sources/Hub/DiscSet.swift`, UI at `AddView.swift:208` to `:232`.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Generate playlists | Present | GagaEmu scans the ROM folder and groups by disc naming |
| Hand-pick discs | Missing | Small value: only for files whose names do not group |

### RomPatcher

![RomPatcher](../maniac-emu-reference-images/walk/07-import-rom-patcher.png)

**Offers:** patch mode and creator mode. Formats listed: IPS, UPS, APS, BPS, RUP, PPF, xdelta. Built on Rom Patcher JS.

**GagaEmu:** `Sources/Hub/RomPatcher.swift`, UI at `AddView.swift:240` to `:260`.

| Item | Status | Detail |
| :--- | :--- | :--- |
| IPS, UPS, BPS | Present | Original left untouched |
| APS, RUP, PPF | Missing | PPF matters most: it is the common format for disc games |
| xdelta | Missing | Common for disc translations. Check the licence of whichever implementation is used |
| Creator mode | Missing | Niche |

## Controllers panel

![Controllers](../maniac-emu-reference-images/walk/08-controllers.png)

**Offers:** assign each input device, touch included, to a player slot. Help and more buttons were not opened.

**GagaEmu:** `Sources/Input/ControllerManager.swift`, slot UI at `Sources/UI/Settings/ControlsViews.swift:303`.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Player slots | Present | Up to four |
| Reach from the library | Partial | GagaEmu's lives in Settings > Controls only |

## Play History panel

![Play History](../maniac-emu-reference-images/walk/09-play-history.png)

**Offers:** a list of played games, empty here.

**GagaEmu:** Continue panel and Recent filter (`LibraryView.swift:117`, `:184`), per-game play time.

| Item | Status | Detail |
| :--- | :--- | :--- |
| History | Present | Populated Manic list was not visible, so finer differences are unknown |

## Settings, General and Advanced

![Settings 1](../maniac-emu-reference-images/walk/10-settings-1.png)
![Settings 2](../maniac-emu-reference-images/walk/11-settings-2.png)

**GagaEmu:** `Sources/UI/Settings/SettingsView.swift`, seven categories at `:16`.

| Manic row | Status | GagaEmu | Detail |
| :--- | :--- | :--- | :--- |
| Membership banner | Present | `Sources/UI/Settings/GagaPlusView.swift` | Behind `PaywallGate` |
| Profile card (nickname, play time, joined) | Missing | None | Removed by the redesign (`docs/02` 2.1) |
| Appearance | Missing | None | See [Theme](#theme) |
| Quick Start | Present | `SettingsView.swift:186` | Opens the most recent game |
| Auto Save States | Partial | `SettingsView.swift:190` | Row is tied to a lock; `docs/02` 2.5 records it as hidden until the entitlement lands |
| Assign Skin | Present | `AssignSkinView.swift` | |
| Cover Scraping | Present | `SettingsView.swift:216`, `Sources/Hub/CoverArtFetcher.swift` | Off by default. Manic's page says only "No compatible games" with an empty library |
| AirPlay Fullscreen | Partial | `Sources/UI/Game/ExternalDisplay.swift`, hidden at `SettingsView.swift:270` | Built, awaiting a second-screen check |
| iCloud Sync | Missing, Blocked | None | No `CloudKit` or ubiquity code. Needs the App ID capability |
| Auto Full Screen | Present | `SettingsView.swift:202` | |
| Respect Silent Mode | Present | `SettingsView.swift:204` | |
| Rumble | Present | `SettingsView.swift:326`, `Sources/Input/RumbleManager.swift` | |
| Skin Sound Effects | Present | `SettingsView.swift:344` | |
| TriggerPro | Present | `SettingsView.swift:525`, `Sources/Input/TriggerProManager.swift` | Manic's page was empty, so its editor is not compared. "Add" was not opened |

## Settings, Support, Others and promotions

![Settings 3](../maniac-emu-reference-images/walk/12-settings-3.png)
![Settings 4](../maniac-emu-reference-images/walk/13-settings-4.png)
![Settings 5](../maniac-emu-reference-images/walk/14-settings-5.png)

| Manic row | Status | GagaEmu | Detail |
| :--- | :--- | :--- | :--- |
| FAQ, Feedback | Partial | Links in About | See [FAQ](#faq) |
| QQ and Discord links | Missing | None | Deliberate |
| About Us | Present | About category | |
| Share | Present | `SettingsView.swift:436` | |
| Clear Cache | Present | `SettingsView.swift:364` | |
| Reset Tips | Present | About | |
| Language | Missing | Hidden row at `SettingsView.swift:453` | No localisation calls under `Sources/`; English only |
| Terms, Privacy | Present | Links | |
| Featured Items, sister-app promo | Missing | None | Deliberate, no player value |
| Rate card | Present | About | System review prompt |

## Theme

![Theme](../maniac-emu-reference-images/walk/15-settings-theme.png)
![Theme 2](../maniac-emu-reference-images/walk/16-settings-theme-2.png)

**Offers:** alternate app icons, theme colours with a custom colour, three cover styles, a corner-radius slider, force square covers, hide title, hide rating badge, games per row (2 to 5), hide scroll indicators, group title style (abbreviation, full, brand), hide group title, sort field and order, manufacturer filter.

**GagaEmu:** fixed palette in `Sources/App/AppTheme.swift`, following the system appearance. Cover rendering in `Sources/UI/Games/CoverArt.swift`.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Games per row | Missing | Most asked-for kind of control; cheap |
| Sort field and order | Missing | No sort option in `LibraryView.swift` |
| Cover style and corners, square covers, hide title | Missing | Display preferences, own design allowed |
| Group title style, hide group title, console order | Missing | Shelf display preferences. `docs/02` 2.5 records console order as not planned |
| Manufacturer filter | Missing | GagaEmu filters by platform chip |
| Appearance override | Missing | No `preferredColorScheme` under `Sources/`. `docs/02` 2.7: not planned |
| Theme colours | Missing | `docs/02` 2.7: not planned, the palette is fixed |
| Alternate app icons | Missing | No `setAlternateIconName`. Needs original icon art |

## Assign Skin

![Assign Skin](../maniac-emu-reference-images/walk/17-settings-assign-skin.png)

**Offers:** per-platform skin list with portrait and landscape tabs, preview, new skin, edit, help and more. States support for `.manicskin` and `.deltaskin`. Only viewed, none selected.

**GagaEmu:** `Sources/UI/Settings/AssignSkinView.swift`, `Sources/UI/Settings/SkinEditorView.swift`, `Sources/Input/TouchSkinEngine.swift`, and portrait since 2026-11-08.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Assign per platform and orientation | Present | |
| Skin editor | Present | `SkinEditorView.swift` |
| `.deltaskin` | Partial | Button positions only, `SkinPackageImport.swift` |
| `.manicskin` | Missing | No handling under `Sources/`. Format must be studied before estimating |

## Cover Scraping

![Cover Scraping](../maniac-emu-reference-images/walk/18-settings-cover-scraping.png)

With no games, Manic only shows a "No compatible games" toast, so its page was not seen. GagaEmu: `CoverArtFetcher.swift`, Status Present, comparison incomplete.

## BIOS

![BIOS](../maniac-emu-reference-images/walk/19-settings-bios.png)

**Offers:** per-system list of named files, each marked Required or Optional with a description and an Import button. Amiga Kickstart sets are visible at the top. No Import was tapped.

**GagaEmu:** `BIOSManagerView` at `SettingsView.swift:646`, with Required, SNES chip firmware and Imported sections and Found or Missing states; import validates name and size (`Sources/App/AppState.swift:1384`).

| Item | Status | Detail |
| :--- | :--- | :--- |
| Required list with presence state | Present | |
| Import on each file row | Missing | GagaEmu imports through the general routes |
| Optional files listed per system | Partial | Depends on core coverage |

## Online Play Settings

![Online Play](../maniac-emu-reference-images/walk/20-settings-online-play.png)
![Nintendo WFC](../maniac-emu-reference-images/walk/21-settings-online-nintendo-wfc.png)
![PSP Networking](../maniac-emu-reference-images/walk/22-settings-online-psp-networking.png)

**Offers:** four sections. Nintendo WFC: choice of replacement servers (Wiimmfi, WiiLink WFC, AltWFC, PKMClassic) plus reset. PSP Networking: enable toggle, and further options not visible. 3DS: Artic Base setup by IP address and Pretendo Network with an install step for Nimbus (labels read from the accessibility tree; see the stop below). Other Netplay: not reached.

**GagaEmu:** local multiplayer only: `Sources/Netplay/` (`NetplaySession.swift`, `LockstepDriver.swift`, `NetplayTransport.swift`, `PlayNearbyView.swift`), entered from `GameView.swift:752` and `LibraryView.swift:309`.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Local multiplayer | Present | Nearby lockstep |
| DS online through WFC servers | Missing | Third-party services; legal review before any UI |
| PSP networking | Missing | No ad hoc code under `Sources/` |
| 3DS Artic Base | Missing | Needs the core's networking and the user's own console |
| 3DS Pretendo | Missing | Third-party service with its own terms |
| Internet netplay | Missing | Manic's own page unseen |

## RetroAchievements

![RetroAchievements](../maniac-emu-reference-images/walk/23-settings-retroachievements.png)

**Offers:** username and password sign-in, create account link. Not filled in.

**GagaEmu:** none; `rcheevos` appears only in the licence list. **Missing, Blocked** on an owner account and approval.

## TriggerPro

![TriggerPro](../maniac-emu-reference-images/walk/24-settings-triggerpro.png)

Empty list with an add button; add was not opened. GagaEmu has `TriggerProManager.swift` plus macro recording in the game menu (`GameView.swift:132`). **Present**, editor not compared.

## JIT

![JIT](../maniac-emu-reference-images/walk/25-settings-jit.png)

**Offers:** JIT status (unavailable on the App Store build), device and OS info, an install link for a sideload build.

**GagaEmu:** none. **Missing, Blocked:** no JIT under App Store rules and dropped by design (`docs/04`, `docs/02` 2.7). Do not add a sideload link to the App Store build.

## Shaders

![Shaders](../maniac-emu-reference-images/walk/26-settings-shaders.png)

**Offers:** search, four tabs (Default, RetroArch, Import, Custom), preview with an image picker, seven default presets, a preview eye and a radio per row, edit button.

**GagaEmu:** `Sources/UI/Settings/FilterPickerView.swift`: live preview, sections, `.metal` and `.slangp` import, parameter sliders and saved presets (`docs/02` 2.3).

| Item | Status | Detail |
| :--- | :--- | :--- |
| Default presets, custom parameters, import | Present | |
| Community shaders | Partial | Three presets against a tab that may be large; Manic's tab was not opened before the stop |
| Search | Missing | Only worth adding once the list grows |
| Own image for preview | Missing | Small |
| GPL shaders (xBRZ, CRT-Royale) | Blocked | Not shipped, replaced by own work (`docs/02` 2.3) |

## Emulator Core

![Emulator Core](../maniac-emu-reference-images/walk/27-settings-emulator-core.png)

**Offers:** default core per platform; long-press a game to switch it for that game. No row opened.

**GagaEmu:** core catalogue in `AppState.swift`, per-game picker in `Sources/UI/Games/CorePickerSheet.swift`, canonical list in `docs/03`. **Present**, except Java ME: **Missing** (spike failed, `docs/07` 6.4).

## FAQ

![FAQ](../maniac-emu-reference-images/walk/28-settings-faq.png)

**Offers:** long embedded guides, including game import, controllers, cheats and skins.

**GagaEmu:** FAQ link only. **Partial**: no guides inside the app. `Sources/UI/TipLine.swift` gives short tips.

## About

![About](../maniac-emu-reference-images/walk/29-settings-about.png)

Embedded page with project, community and legal links. GagaEmu: About category and `Sources/UI/Settings/LicencesView.swift`. **Present.**

## Paywall

![Paywall](../maniac-emu-reference-images/walk/30-paywall.png)

Shown and backed out; no control on it was used. Plans and five feature cards match `docs/02` 2.6. GagaEmu: `GagaPlusView.swift`, `Sources/Store/StoreKitManager.swift`. **Present**, behind `PaywallGate`.

## GagaEmu has, Manic lacks (or was not seen to have)

Nothing below was seen in Manic. Items marked "unseen" could exist on pages the walk could not reach.

- Rewind, with hold button and controller chord (`GameView.swift:177`). Unseen in Manic's settings.
- Macro recording from the pause menu (`GameView.swift:132`). Unseen.
- Live shader preview while choosing, and named saved parameter presets (`FilterPickerView.swift`).
- Own Screen Layout Editor (`Sources/UI/Settings/ScreenLayoutEditorView.swift`). Unseen.
- Nearby local multiplayer with encrypted transport (`Sources/Netplay/NetplayCrypto.swift`). Manic's "Other Netplay" page was not reached, so this comparison is open.
- Wi-Fi import guarded by a session PIN. Manic's Wi-Fi PIN behaviour unseen.
- Emulation is free for every core, with no platform gated (`docs/02` 2.6).
- Keyboard input mapping editable per system and game (`Sources/Input/ControlMapping.swift`).

## Second walk, game pages (2026-11-09)

The owner allowed importing games into Manic and playing them. Games went in through Manic's Wi-Fi transfer, driven from the phone itself. No purchase, sign-in or terms were accepted, no game was deleted, and no setting changed beyond switching Wi-Fi transfer on for the import. Screens below are from Manic EMU 2.0.2 on the same iPhone 17.

### Game detail and long-press menu

Screenshots not embedded (`32-game-long-press.png`, `33-game-detail.png`): they show game titles and cover art.

![Game more menu](../maniac-emu-reference-images/walk/31-game-more-menu.png)

**Offers:** tapping a game opens a detail page with cover, description, Play Now, Safe Mode and View Metadata. Long press, and the carousel's more button, give Rename, Edit Cover, Assign Skin, View Save States, Import Game Save, Export Game Save, RetroAchievements and Cheat Codes, plus a Listen with BitBop sister-app promotion. Portrait shows a grouped grid with a system index and search; landscape shows a cover carousel with Play and more buttons. Games get cover art from a scraped database.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Rename, edit cover, assign skin per game | Present | Long-press menu on the Library |
| Import and export a game save | Present | `Sources/UI/Game/ManageSavesSheet.swift`, `Sources/Session/SaveStore.swift` |
| Safe Mode launch | Missing | No matching code in `Sources/` |
| Sister-app promotion | Not planned | Same reason as the other promotions |

### In-game menu, skin and speed

![In-game menu 1](../maniac-emu-reference-images/walk/34-ingame-menu-1.png)
![In-game menu 2](../maniac-emu-reference-images/walk/35-ingame-menu-2.png)
![In-game menu 3](../maniac-emu-reference-images/walk/36-ingame-menu-3.png)
![Assign skin in game](../maniac-emu-reference-images/walk/39-ingame-assign-skin.png)

**Offers:** a sheet opened by the skin's menu button, with quick buttons for quit, reset, save state and load state. Rows: Assign Skin (per game, portrait and landscape), View Save States, RetroAchievements, Cheat Codes, Core Settings, Save State, Quick Load, Volume, Fast Forward, Slow Motion, Shaders, Screenshot, Haptics, AirPlay, Controllers, Dead Zone.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Fast forward | Present | `Sources/UI/Game/GameView.swift` |
| Slow motion | Missing | No matching code in `Sources/` |
| Dead zone | Present | `Sources/UI/Settings/ControlsViews.swift` |

### Save states

![Save states](../maniac-emu-reference-images/walk/38-ingame-save-states.png)

**Offers:** Manual Save States and Auto Save States tabs. Empty on the tested game, so the list and its row actions were not seen.

### Cheats

![Cheats](../maniac-emu-reference-images/walk/37-ingame-cheats.png)

**Offers:** an empty list with Add Cheat Codes. The add form was not opened.

### Shaders, RetroArch tab

![Shaders RetroArch tab](../maniac-emu-reference-images/walk/40-settings-shaders-retroarch.png)

**Offers:** tabs Default, RetroArch, Import and Custom. The RetroArch tab is empty until the user taps Download Shaders from RetroArch, so the size of the catalogue is still unseen; the download was not started.

### Other Netplay

![Other Netplay](../maniac-emu-reference-images/walk/42-settings-other-netplay.png)

**Offers:** Announce Publicly (public lobby), Use Relay Server, Server Password, Spectator Mode, Spectator Password.

| Item | Status | Detail |
| :--- | :--- | :--- |
| Relay server | Partial | `Sources/Netplay/NetplayTransport.swift` mentions relay; not compared in detail |
| Public lobby, passwords, spectator mode | Missing | No spectator code in `Sources/` |

### 3DS Pretendo Network

![Pretendo](../maniac-emu-reference-images/walk/43-settings-pretendo.png)

**Offers:** Artic Base transfer from a real 3DS by IP address with a Start Transfer button, then Install Nimbus for Pretendo. No iOS Local Network prompt appeared this time. Nothing was started.

### Terms of Service and Language

![Terms](../maniac-emu-reference-images/walk/41-settings-terms.png)
![Language row](../maniac-emu-reference-images/walk/44-settings-language-row.png)

Terms of Use open as a web page in an in-app browser; there is nothing to accept. The Language row shows the current language. Tapping it twice ended the walk with the test connection to Manic lost, consistent with leaving the app, so the destination was not captured.

### Import behaviour

- Wi-Fi transfer is a GCDWebUploader page on port 6969. Each uploaded file is imported on its own.
- A `.zip` raises a ZIP File Handling sheet, one per archive, asking whether to extract or keep it as a ZIP ROM. The walk uploaded extracted ROMs instead.
- Cue sheets sent file by file fail with "Missing file", and each `.bin` becomes its own entry. Disc games need a different route, such as a ZIP, which was not tried.
- Identical ROMs are refused as already existing. 3DS and PSP titles appear to come from the game data, not the file name.
- `.bin` cartridge ROMs land in Unknown Platform and do not launch. Two BIOS or data files with a `.rom` extension were classed as Jaguar; launching one crashed Manic.
- One 3DS game raised the iOS camera permission prompt while running. It was not answered.

### Boot comparison by system

Manic: launched about 20 s, counted when the screenshot at 20 s showed a game picture (non-black, spot-checked by eye). Manic showed no fps counter on the tested screens, so no fps was recorded. GagaEmu: counts from device run 20 (launched with a real frame and audio).

| System | Manic boots | GagaEmu boots | Note on Manic |
| :--- | ---: | ---: | :--- |
| 3DS | 1 | 1 | Only one of four uploaded dumps was imported; one more failed to extract on the Mac |
| FDS | 0 | 2 | Both returned to the library; BIOS not imported, as it was outside the allowed data change |
| GB | 4 | 4 | |
| GBC | 4 | 5 | One id not found in the library after upload |
| GBA | 13 | 13 | |
| MEGADRIVE | 0 | 4 | Two `.bin` ROMs in Unknown Platform; three CD games blocked by the cue issue above |
| N64 | 3 | 3 | |
| NDS | 8 | 8 | One `.rar` id was not extracted |
| NES | 8 | 8 | |
| PS1 | not tested | 6 | Cue issue above |
| PSP | not tested | 4 | Imported, but the walk could not find them under their ids, so none was launched |
| Saturn | not tested | 0 | Archive failed to extract on the Mac |
| SNES | 10 | 10 | |
| Total | 51 | 68 | Not a like-for-like total: PS1, PSP, Saturn and the disc games were not launched on Manic |

Differences worth noting: FDS and Mega Drive `.bin` are the systems where Manic did worse here, both from import handling rather than from emulation. Where both launched, there is no measured fps to compare.

## Pages not reached

| Page | Why |
| :--- | :--- |
| Language destination | Tapping the row lost the walk's connection to Manic; only the row is captured |
| Save state list items, cheat add form | Empty on the tested game; adding would create data |
| Files picker, Read Clipboard | Files picker was not used; clipboard raises an iOS paste prompt |
| Other switches | Toggling is not allowed |
| Cloud provider rows | Each starts a sign-in |
| RetroAchievements account flow | Sign-in |
| Feedback, Join QQ, Join Discord, Share, Clear Cache, Reset Tips, Rate Us, sister-app promo | Leaves the app, or changes data |
| TriggerPro add, skin new or edit, core picker rows, BIOS import | Would create or change data |
| Add Game Link, import from other emulators, sideload install | Would start an action |
| Membership purchase flow | Paywall only screenshotted |
