# Manic EMU feature TODO

GagaEmu's UI stays an original design; Manic EMU is a feature reference only, so nothing here asks to copy its layout, labels or art.

Items: 41 open, 63 done (104 total).

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
- [x] Cover display: Spine, Plain and Framed styles, corner radius, square covers, hide game title, hide details (Settings > Display).
- [x] Hide scroll indicators toggle.
- [x] Shelf title style (full name, short code, maker) and hide shelf title.
- [x] Manufacturer filter, in the Library's sort menu.
- [ ] Console order. Recorded as not planned in `docs/02` 2.5. (P3, S, blocked: not planned)
- [x] Reach the controllers panel from the library, through the sort menu.
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
- [x] MultiDisc helper: hand-pick discs whose names do not group.
- [x] Download queue for files from the user's own WebDAV or RomM server: runs one at a time, keeps going after the sheet closes, cancel and failure rows on Add. Rows and cancel pass on the iPhone with seeded jobs, and a queued download passes over loopback; not run against a real server over Wi-Fi.
- [ ] Add game by link. GagaEmu rejects web links on purpose. (P3, M, blocked: App Store rule)

## Cloud and sync

![Add Service](../maniac-emu-reference-images/walk/05-import-add-service.png)
![Settings, Advanced (iCloud Sync row)](../maniac-emu-reference-images/walk/11-settings-2.png)

- [x] iCloud sync of saves and save states, optionally ROMs, off by default in Settings, Storage. `Sources/Hub/CloudSync.swift`, container `iCloud.com.zenithblue.gagaemu`, in build 202611092335. Conflict unit tests and the Settings walk pass on iPhone. (P1, L)
- [ ] Check iCloud sync between two real devices signed in to one account, including iCloud's own file-version conflicts. Needs the owner. Library metadata (play time, favourites) does not sync, and a deletion does not travel. (P1, S, needs owner)
- [ ] WebDAV as a game source. Built (`Sources/Hub/WebDAVClient.swift`, Add > WebDAV Server). Sign-in, browse, download and refusal of unsafe paths pass on the iPhone against a loopback server only; not yet run against a real server over Wi-Fi. (P2, M)
- [ ] SMB network share as a game source. Partial: through the Files app's Connect to Server, then Choose from Files (Add > SMB Share, guide written). Not run against a share. An in-app client needs libsmb2 (LGPL), so it was not added. (P2, M)
- [ ] Google Drive, Dropbox and OneDrive browse and import. Each needs an OAuth client and a file browser. Confirm against App Review 4.7 first. (P2, L, blocked: owner account)
- [ ] RomM server as a game source (self-hosted library). Built (`Sources/Hub/RomMClient.swift`, Add > RomM Server), the user brings the server, with WebDAV's security rules. Sign-in, systems, paged lists, download and refusal of plain HTTP pass on the iPhone against a loopback server only; written from RomM's source and not yet run against a real server. Games made of several files are hidden. (P3, M)
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
- [ ] Internet netplay beyond local play ("Other Netplay"). Manic's page is captured in the gap analysis. (P3, L, blocked: legal review)

## Achievements

![RetroAchievements sign-in](../maniac-emu-reference-images/walk/23-settings-retroachievements.png)

- [x] RetroAchievements sign-in and in-game achievements. The player signs in with their own account; see "Owner requests, 2026-11-09". (P1, M) Built on rcheevos v12.5.0: settings sign-in, token in Keychain, unlock toast, list with progress, hardcore gates. Unit tests with a fake server and a synthetic set pass on iPhone; a real server sign-in is unverified, and hardcore needs RetroAchievements approval of GagaEmu.

## Skins

![Assign Skin](../maniac-emu-reference-images/walk/17-settings-assign-skin.png)

- [x] Assign a skin per platform and orientation, portrait and landscape (`Sources/UI/Settings/AssignSkinView.swift`).
- [x] Skin editor (`Sources/UI/Settings/SkinEditorView.swift`).
- [ ] `.deltaskin` skins. Partial: the same editor Import as `.manicskin` reads the real Delta schema for button positions; the art is not used, and no real skin file was tried. (P2, M)
- [x] Skin sound effects toggle.
- [ ] Read `.manicskin` skins. Partial: the skin editor's Import reads button positions from a `.manicskin` or `.deltaskin` (`Sources/Input/SkinPackageImport.swift`); the art is not used. Passes on the iPhone with generated files only; no real skin file tried, and the file picker step cannot be automated. (P2, M)

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
- [x] Patch creator mode: Patch a ROM > Create writes a UPS patch from two ROMs, shared or saved through the system sheet. The screen and round trip pass on the iPhone; choosing a file in the system picker cannot be automated.
- [x] xdelta patches, with djw, lzma and fgk secondary compression (`Sources/Hub/Xdelta.swift`). Round trips pass on the iPhone against our own encoders; no patch made by the real xdelta3 tool has been tried yet.

## Shaders and filters

![Shaders](../maniac-emu-reference-images/walk/26-settings-shaders.png)

- [x] Default presets with live preview (`Sources/UI/Settings/FilterPickerView.swift`).
- [x] Custom parameters, `.metal` and `.slangp` import, saved presets.
- [x] Browsable catalogue. 73 in-house filters with a browsable picker (`docs/shader-catalogue.md`) pass the iPhone walks, and `testSlidersChangeTheFilterThatUsesThem` passes on the iPhone (2026-11-09). GPL shaders below stay open. Was a must, see "Owner requests, 2026-11-09". (P1, L)
- [x] Filter list search.
- [x] Pick your own image for the filter preview, from the system photo picker, for this run of the app, with a way back to the built-in picture. Passes on the iPhone through a seeded picture; choosing in the system picker cannot be automated.
- [ ] GPL shaders (xBRZ, CRT-Royale). Not shipped, replaced by own work. The owner accepts GPL; see "Owner requests, 2026-11-09". (P2, M)

## Themes and appearance

![Theme, app icons and colours](../maniac-emu-reference-images/walk/15-settings-theme.png)

- [x] Appearance choice: dark, light or automatic (Settings > Display).
- [x] Accent colours with a custom colour; any colour is adjusted to meet AA.
- [ ] Alternate app icons. Partial: Settings > Display offers five original icons from `design/icons`, and the bundle and picker pass on the iPhone. Changing the icon raises a system notice the walk must not answer, so the change itself is not run. (P3, M)

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
- [x] Auto Save State toggle in Settings > Play. Quit then play offers Resume. It becomes a Plus item only if the paywall gate opens (`docs/06` section 4).
- [ ] Language selection. Partial: `Resources/Localizable.xcstrings` with about 30 Settings and navigation strings in Spanish and French, none reviewed by a native speaker; the rest is English. Spanish passes on the iPhone, French not run. (P2, M)
- [ ] AirPlay fullscreen. Partial: toggle now in Settings > Graphics, off by default, awaiting a second-screen check. (P2, S)
- [ ] Profile card with nickname, play time and join date. Removed by the redesign (`docs/02` 2.1). Screenshot not embedded, see the end. (P3, S, blocked: not planned)
- [ ] Featured items and sister-app promotion. Deliberate, no player value. (P3, S, blocked: not planned)
- [ ] Discord and QQ links. Deliberate. (P3, S, blocked: no community channel)

## BIOS

![BIOS list](../maniac-emu-reference-images/walk/19-settings-bios.png)

- [x] Required BIOS list with Found or Missing state; import validates name and size (`Sources/App/AppState.swift:1384`).
- [x] Import button on every BIOS file row. The button opens the file picker on the device; choosing a file there cannot be automated, and the copy and size check pass their tests.
- [x] Files listed under Required and Optional sections in the BIOS list.

## Emulator cores

![Emulator Core](../maniac-emu-reference-images/walk/27-settings-emulator-core.png)

- [x] Default core per platform, and per-game core picker (`Sources/UI/Games/CorePickerSheet.swift`).
- [ ] Java ME platform. Spike failed (`docs/07` 6.4). (P3, L, blocked: spike failed)

## JIT

![JIT status](../maniac-emu-reference-images/walk/25-settings-jit.png)

- [ ] JIT mode per core, development build only; see "Owner requests, 2026-11-09". Never in App Store or TestFlight builds, and no sideload link in them. The option exists in the DevJIT configuration; no JIT does. (P2, L)

## Help and about

![FAQ](../maniac-emu-reference-images/walk/28-settings-faq.png)
![About](../maniac-emu-reference-images/walk/29-settings-about.png)

- [x] About page with project and legal links.
- [x] Inline guides inside the app (import, network folders, controllers, cheats, skins), Settings > About > Guides.

## Membership

- [x] Paywall with plans and five feature cards (`Sources/Store/StoreKitManager.swift`, matches `docs/02` 2.6). Screenshot not embedded, see the end.

## Pages not captured yet

The gap analysis could not reach these. Each is a task to capture.

- [x] Capture game detail and the long-press menu on a populated library. (P2, S)
- [x] Capture the in-game menu, including skin and speed options. (P2, S)
- [x] Capture save states. Empty list only. (P2, S)
- [x] Capture cheats. Empty list only. (P2, S)
- [x] Capture 3DS Pretendo Network. No Local Network prompt this time. (P3, S)
- [x] Capture Other Netplay. (P3, S)
- [x] Capture the Shaders RetroArch tab. Empty until a download the walk did not start. (P3, S)
- [ ] Capture Language. Row only: tapping it lost the walk's connection to Manic, so the destination is unseen. (P3, S)
- [x] Capture Terms of Service. (P3, S)

## Found in the game-page walk, 2026-11-09

- [ ] Safe Mode launch from the game detail page. Manic's behaviour behind the button was not explored. (P3, S)
- [ ] Slow motion in the in-game menu, next to fast forward. (P3, S)
- [ ] Netplay public lobby, server and spectator passwords, and spectator mode. Manic's Other Netplay page lists them. (P3, L, blocked: legal review)

## Owner requests, 2026-11-09

Sources and plans for cheats: `docs/cheats-sources.md`.

- [x] Cheats for every core that can have them (2026-11-10). A host poke engine (`Sources/Bridge/PokeEngine.swift`) serves atari800, beetle_ngp, beetle_vb, flycast, handy, pokemini, prosystem, puae, stella, vice and virtualjaguar; a real-core test on the iPhone shows a poke changing RAM on each, using homebrew fixtures. azahar takes Gateway codes through upstream's engine and prboom takes Doom cheat words; on the iPhone both accept codes and keep running, but their effect in a game is not observed. dosbox_pure stays out: it exposes no memory and its cheat call is a stub. No bundled code has been tried in the commercial game it was written for. (P1, L)
- [x] Bundle the libretro `cht` collection as the cheat database, with credit on the licences screen. `Resources/cheats.pack`, about 10 MB, 28 systems. A bundled cheat switched on in a running game passes on the iPhone (Handy, homebrew, looked up under a real title by a debug setting). (P1, M)
- [ ] Shaders are a must: a large catalogue, a proper visual preview UI, and every core that supports shaders. (P1, L)
- [ ] RetroArch shader catalogue and GPL shaders (xBRZ, CRT-Royale and similar). Owner accepts GPL. Where a licence forbids use, write a clean engineered replacement. Add to the licences screen. (P1, M)
- [x] xdelta patches, including secondary compression (djw, lzma), clean engineered. Licence tag removed. (P2, M)
- [x] RetroAchievements: a real implementation on rcheevos. The player signs in with their own account in the app; no shared credentials. (P1, M) Built on rcheevos v12.5.0: settings sign-in, token in Keychain, unlock toast, list with progress, hardcore gates. Unit tests with a fake server and a synthetic set pass on iPhone; a real server sign-in is unverified, and hardcore needs RetroAchievements approval of GagaEmu.
- [x] iCloud sync of saves and save states, with optional ROMs. Capability and container registered 2026-11-09. Real two-device sync is unverified, and library metadata does not sync; see the iCloud items above. (P1, L)
- [ ] Google Drive, Dropbox and OneDrive browse and import. Owner will supply access; the owner enters credentials themselves. Check App Review 4.7 first. (P2, L, needs owner: client IDs and capability)
- [ ] JIT mode per core as an option, development build only. NEVER in App Store or TestFlight builds: gate it at compile time so release targets cannot contain it. (P2, L) Option only so far: a per-game "JIT mode (not functional)" toggle in the core picker, compiled only in the DevJIT configuration, for the 10 cores with an arm64 recompiler upstream (`docs/04` section 8.1). It stores a preference and enables nothing; `scripts/nojit-gate.sh` fails any Release, archive or IPA holding it. The JIT itself is future work.

## Screenshots not embedded

- `10-settings-1.png`: shows the profile card with the nickname and join date, which is personal info.
- `30-paywall.png`: background shows cover art with game titles.
- `32-game-long-press.png`: shows game titles in the library behind the menu.
- `33-game-detail.png`: shows a game title, cover art and description.
- `45-3ds-camera-prompt.png`: shows game art behind the iOS camera prompt.
