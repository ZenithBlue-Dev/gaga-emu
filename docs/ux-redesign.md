# GagaEmu UX Redesign Plan

Status: built 2026-11-10, batches 1-10 (see "Build status" at the end). Plan written 2026-11-10 from the owner's feedback, the code on `main` (11213c4), and the walk screenshots of 2026-11-09 (`testAuditScreens`, `testAuditManic2`, `testAuditManic3`, `testAuditDisplay`, `testAuditGameGBA`). Those screenshots stay outside the repo. Each reference below names the walk test and the attachment label, for example `Screens/06 Settings Controls portrait`.

Owner feedback, in short:

1. "UI/UX is very bad. I can't find anything in the app."
2. "All options should show an image of what it is."
3. "Why do games show the core name as user? Use the user name, or name it GagaEmu."

Constraints that hold for every change here:

- The UI stays original: Paper and Ink (`docs/DESIGN.md`). Manic EMU and Delta are feature references only. No art, logos, labels or layouts are copied from them.
- Portrait and landscape, iPhone and iPad.
- Dynamic Type, VoiceOver, contrast (the AA test in `Tests/GagaEmuTests.swift`) and Reduce Motion must keep working.
- SwiftUI on iOS 17, with what the codebase already has: `AppTheme`, `ValueRow`, `ToggleRow`, `ActionRow`, `SkinThumbnail`, `PaperSheet`, `TipLine`, the `FilterPickerView` live preview and the `AppIconPicker` previews.

## 1. Current navigation map

Root: `Sources/UI/RootView.swift`. There are three tabs: Library, Add and Settings. Upright on a phone they are a bottom bar. Otherwise they are a left rail (`LeftRail`).

| Depth | Path | Screen | Source |
|---|---|---|---|
| 0 | Library | Continue card, tip, platform chips, sort menu, search, shelves | `Games/LibraryView.swift` |
| 1 | Library > sort menu | Sort By, Order, Maker, **Controllers** | `LibraryView.swift:205-216` |
| 1 | Library > touch and hold a game | Play, Play Nearby, Change Core, Choose Filter, Assign Skin, Manage Saves, Edit Details, Delete | `LibraryView.swift:355-362` |
| 2 | ... > Manage Saves | Save slots, Cheats | `Game/ManageSavesSheet.swift` |
| 0 | Add | Files, WebDAV, RomM, Multi-Disc, Patch, downloads | `Import/AddView.swift` |
| 0 | Settings | 7 categories (9 with Cores and Gaga Plus) | `Settings/SettingsView.swift:17-23` |
| 1 | Settings > Play | Play time, Sessions, Quick Start, Auto Save State, Rewind, **RetroAchievements**, Auto Full Screen, Respect Silent Mode | `SettingsView.swift:183-220` |
| 1 | Settings > Library | Games count, Cover Art, Refresh Covers, **BIOS Files**, default core per platform | `SettingsView.swift:222-267` |
| 1 | Settings > Display | App Icon, Appearance, Accent Colour, **shelf and cover layout** | `Settings/DisplayPane.swift` |
| 1 | Settings > Graphics | Default Filter, Screen, AirPlay Full Screen | `SettingsView.swift:269-291` |
| 2 | ... > Default Filter | Filter list with live preview | `Settings/FilterPickerView.swift` |
| 2 | ... > Screen | Scaling and dual-screen layouts | `Game/ScreenOptionsForm.swift` |
| 1 | Settings > Controls | Touch Control, **Touch Layout ("Skins and editor")**, Controller Mapping, Macros, Turbo, Touch Haptics, Hide Touch, Rumble, Rumble Strength, Skin Sound Effects | `SettingsView.swift:293-366` |
| 2 | ... > Touch Layout | Assign Skin: layout cards, per-system pickers, Edit | `Settings/AssignSkinView.swift` |
| 3 | ... > Edit | Skin editor | `Settings/SkinEditorView.swift` |
| 1 | Settings > Cores | Per-core options (in progress on another branch of work) | `Settings/CoreOptionsView.swift` |
| 1 | Settings > Storage | Game files size, iCloud Sync, Include Game Files, iCloud status, Clear Cache | `SettingsView.swift:376-415` |
| 1 | Settings > About | Version, About Us, Share, **Guides**, Licences | `SettingsView.swift:440-515` |
| 0 | In game > pause | Resume, Save State, Load State, Screen, Controls, Core Options, Quick Slot, Record Macro, Achievements, Hardcore, Cheats, Quit | `Game/GameView.swift:645-800` |

### Taps to reach the 20 most-used features

Counted from the Library tab, in the current build.

| # | Feature | Taps | Path | Findable? |
|---|---|---|---|---|
| 1 | Resume last game | 1 | Continue > Play | Yes |
| 2 | Start any game | 1-2 | Tile, then Resume or Start Over | Yes |
| 3 | Import from Files | 2 | Add > Choose from Files | Yes |
| 4 | Save state | 2 | Pause > Save State | Yes |
| 5 | Load state | 3 | Pause > Load State > slot | Yes |
| 6 | Fast forward | 1 | In-game button | Yes, icon only |
| 7 | **Change skin, all games** | 4 | Settings > Controls > Touch Layout > picker | **No**, the word "skin" is only in a grey value |
| 8 | Change skin, one game | 3 | Touch and hold > Assign Skin > pick | Hidden gesture |
| 9 | Edit skin layout | 4 | Settings > Controls > Touch Layout > Edit | **No** |
| 10 | Default filter | 3 | Settings > Graphics > Default Filter | So-so, "Graphics" vs "Display" |
| 11 | Filter, one game | 3 | Touch and hold > Choose Filter | Hidden gesture, not in pause menu |
| 12 | Change core | 3 | Touch and hold > Change Core | Hidden gesture |
| 13 | Core options | 2 | Pause > Core Options | Only in a game, or Settings > Cores |
| 14 | Cheats | 2-3 | Pause > Cheats, or Manage Saves > Cheats | So-so |
| 15 | Controller mapping | 3 | Settings > Controls > Controller Mapping | Yes |
| 16 | **Controller player slots** | 2 | Library sort menu > Controllers | **No**, it hides in a sort menu |
| 17 | **BIOS files** | 3 | Settings > Library > BIOS Files | **No**, BIOS is not a library setting |
| 18 | **RetroAchievements sign-in** | 3 | Settings > Play > RetroAchievements | **No**, "Play" does not say accounts |
| 19 | iCloud Sync | 3 | Settings > Storage > toggle | So-so |
| 20 | **Library layout (per row, covers)** | 2 | Settings > Display | **No**, it is not under Settings > Library |

Also: Rewind (Settings > Play), Guides (Settings > About > Guides, 3 taps), Play Nearby (touch and hold, 2 taps), App Icon (Settings > Display).

## 2. Bug: the core name is shown as the player name

### What the owner sees

DS games show the firmware nickname "melonDS DS". PSP games show the nickname "PPSSPP". 3DS games show Azahar's built-in profile name. Each core uses its own name because GagaEmu never gives it the player's name.

### Root cause

Libretro cores ask the frontend for a name with `RETRO_ENVIRONMENT_GET_USERNAME` (38). `lr_environment` in `Cores/shared/LibretroAdapter.c:648-724` has no case for it, so the call falls to `default:` (line 712) and returns `false`. Each core then uses its fallback:

- melonDS DS: `Cores/melonds_ds/upstream/src/libretro/environment.cpp:586` asks. The default mode is `guess_username` (`config/definitions/firmware.hpp:106`). When the frontend has no name it tries the `USER` environment variable, which on iOS can give `mobile`. After that it uses `DEFAULT_USERNAME = "melonDS DS"` (`config/constants.hpp:191`, `config/console.cpp:1269`).
- PPSSPP: `Cores/ppsspp/upstream/libretro/libretro.cpp:1237-1239` asks and keeps the default `sNickName`, which is "PPSSPP" (see `Core/Config.cpp:635`).
- Azahar: `citra_libretro` never asks for a name, so the 3DS profile keeps the emulator's default. The fix is to call `Service::CFG::Module::SetUsername` (`core/hle/service/cfg/cfg.cpp:1171`) from `Cores/azahar/AzaharSupport.cpp` after boot. Check the 3DS System Settings name on the device after the fix.

There is a related leak. Netplay sends `UIDevice.current.name` as the player name (`Sources/Netplay/NetplaySession.swift:140`) and as the Bonjour service name (line 147). On iOS 16 and later that value is the generic "iPhone" or "iPad", not a person's name.

### Does the app have a player name?

No. GagaEmu has no player name or profile setting. Two names exist:

- The Game Center alias. `Sources/App/GameCenter.swift` signs the player in. The banner in `Screens/01 Library portrait` shows an auto-made alias. Nothing reads `GKLocalPlayer.local.alias`.
- The RetroAchievements login. `Sources/Session/RetroAchievements.swift:42` holds it, and only for that service.

### Smallest fix

1. Add one `@AppStorage("playerName")` string to `AppState`. Show it as a "Player Name" text field at the top of Settings (section 4). When it is empty, the effective name is the Game Center alias if Game Center is signed in, else `"GagaEmu"`.
2. Sanitize the effective name once, in Swift: keep `A-Z a-z 0-9 _ -`, cut it to 16 characters, and use `"GagaEmu"` if fewer than 3 are left. PPSSPP accepts 3-16 of those characters. melonDS cuts names to 10 characters itself.
3. Before a core loads, call `setenv("GAGA_USERNAME", name, 1)`. Each core framework compiles its own copy of the adapter, so an environment variable reaches all of them without a new export per framework.
4. In `lr_environment` add the case below. It copies the value, so the pointer stays valid after a later `setenv`.

```c
case RETRO_ENVIRONMENT_GET_USERNAME: {
    static char name[33];
    const char* v = getenv("GAGA_USERNAME");
    snprintf(name, sizeof name, "%s", v && *v ? v : "GagaEmu");
    *(const char**)data = name;
    return true;
}
```

5. Azahar: read the same variable in `AzaharSupport.cpp` and call `SetUsername` after boot.
6. Netplay: send the effective name in place of `UIDevice.current.name` at `NetplaySession.swift:140` and `:147`.
7. Test: add a unit test that the sanitizer returns `"GagaEmu"` for an empty or emoji-only name. Then do one device walk that opens a DS game and checks the firmware name.

The name goes into the DS firmware and save states. A changed name applies at the next game start. Say this in the field's footnote.

## 3. Research

### Apple Human Interface Guidelines

- **Settings.** "Minimize the number of settings you offer", because too many make a setting hard to find. Settings that affect one task should be "within the task itself". Do not ask for what the app can detect, for example a connected controller. Source: <https://developer.apple.com/design/human-interface-guidelines/settings>.
  - For GagaEmu: put per-game choices (filter, skin, core, cheats) in the pause menu and on a game page, not only in Settings. Controllers should be detected and shown, not hidden in a sort menu.
- **Tab bars.** Tabs are "to support navigation, not to provide actions". Use single-word labels. Never hide or disable a tab. On iPad, prefer a tab bar that can become a sidebar. Source: <https://developer.apple.com/design/human-interface-guidelines/tab-bars>.
  - For GagaEmu: four single-word tabs, the same in both orientations. iPad uses `.tabViewStyle(.sidebarAdaptable)` on iOS 18 and keeps the current rail on iOS 17.
- **Search fields.** Use placeholder text that says what can be found. Show recent searches and suggestions. Start with a broad scope and let people narrow it with a scope bar. Source: <https://developer.apple.com/design/human-interface-guidelines/search-fields>.
  - For GagaEmu: one settings search with the prompt "Search settings, like skin or BIOS". It shows recent searches and has scopes All, This Game and App.
- **In-game menus and games.** Players navigate in-game menus with the platform's usual input. Buttons must be at least 44 by 44 pt. Text must stay legible on every display. Sources: <https://developer.apple.com/design/human-interface-guidelines/menus> (In-game menus) and <https://developer.apple.com/design/human-interface-guidelines/designing-for-games>.
- **Accessibility.** Support Dynamic Type, label images for VoiceOver, and respect Reduce Motion. Source: <https://developer.apple.com/design/human-interface-guidelines/accessibility>.

### Emulator and game-library apps (feature reference only)

- **Delta.** Its guide names features in plain words: Pausing, Save States, Controller Skins, Fast Forward, Cheat Codes, Hold Buttons. Skins have their own "Controller Skins" list in settings, grouped by system. The pause menu holds save and load, cheats, fast forward and held buttons. Sources: <https://faq.deltaemulator.com/using-delta/controller-skins> and <https://faq.deltaemulator.com/using-delta/pausing>.
  - What to learn: call a skin a "skin", give it a visible top-level entry, and put the per-game tools in the pause menu.
- **Provenance.** It lists Controller Skins, Video Filters (named CRT, LCD, VHS styles), Save States, Cheats and RetroAchievements as top features, and adds a side menu and a save-state browser in recent versions. Source: <https://github.com/Provenance-Emu/Provenance> (README).
  - What to learn: show filters as named looks, and save states as pictures.
- **RetroArch.** The Quick Menu opens over a paused game and holds the core options, shaders, remapping and overrides for content, folder or core. Source: <https://docs.libretro.com/guides/quick-menu/>.
  - What to learn: one in-game place for everything about this game. Its known weak point is deep menus with no pictures, which is GagaEmu's problem too.
- **Manic EMU.** Its site groups "saves, speed, cheats, shortcuts, filters, and skins" as in-game tools, and offers a landscape library that can be browsed with a controller. Source: <https://manicemu.site/>.
  - This is a feature reference only. Nothing visual is taken from it.
- **Console library UIs (Steam Deck, Switch, PlayStation).** The common pattern is a cover-first library, a per-game page (Play, settings for this game, saves) and a quick-access overlay during play. Settings use icons plus a short label and have a search. This is general industry practice, not copied from any one product.

What this means for GagaEmu:

1. Name features the way players say them: Skins, Filters, Save States, Cheats, Controllers, BIOS.
2. Every per-game tool is reachable both from a visible game page and from the pause menu, not only from a hidden gesture.
3. Settings get search, and every row gets a picture.

## 4. Problems, ranked by severity

| # | Severity | Problem | Evidence |
|---|---|---|---|
| 1 | High | **Skins cannot be found.** They sit under Controls > "Touch Layout" with "Skins and editor" as a grey value. The editor is 4 taps deep. | `Screens/06 Settings Controls portrait`, `Screens/07 Assign Skin portrait`; `SettingsView.swift:323` |
| 2 | High | **No settings search.** About 60 rows sit across 7-9 categories, and nothing can be searched. | `SettingsView.swift` has no `.searchable` |
| 3 | High | **Category names overlap.** Display vs Graphics. Library layout is in Display. BIOS is in Library. RetroAchievements and Rewind are in "Play". Guides are in About. | Section 1 table |
| 4 | High | **The core name is shown as the player name** in DS, PSP and 3DS games. Netplay sends a generic device name. | Section 2 |
| 5 | High | **Per-game actions hide behind touch and hold.** A permanent tip banner tries to explain the gesture and takes space on the Library screen. | `Screens/01 Library portrait`, `Screens/02 Library menu portrait` |
| 6 | Medium | **Options have no pictures.** Rows are text plus a monospaced value. Only the filter picker, the skin layout cards and the app icons show images. | `Screens/06 Settings Graphics portrait`, `Screens/06 Settings Controls portrait` |
| 7 | Medium | **Controllers hide in the sort menu.** | `Manic2/40 Sort menu with maker`, `Manic2/41 Controllers from Library` |
| 8 | Medium | **The pause menu is a long text list with no icons.** It has no Filter or Skin entry. "Screen: Fit" does not explain itself. In portrait it covers the lower half and scrolls. | `GameGBA/10 GBA Pause portrait` |
| 9 | Medium | **Settings tabs wrap upright.** On a phone, 7-9 text-only categories wrap into two rows with an underline, which looks like body text, not navigation. | `Screens/06 Settings Controls portrait` |
| 10 | Medium | **Walls of footnote text.** Almost every toggle has a 1-3 line note, and the Rewind note runs to five lines. Values use monospaced caption text. At large Dynamic Type sizes a screen holds 2-3 rows. | `Screens/06 Settings Play portrait` |
| 11 | Low | **The landscape Library is cramped.** Search is cut off ("GagaBenc…"), the chips are crowded, and the Continue card takes half the width. | `Screens/01 Library landscape` |
| 12 | Low | **Add is a tab.** HIG says tabs are for navigation, not actions. It is acceptable here because Add has its own content (sources, downloads), but it should read as a place: "Import". | `Screens/04 Add portrait` |

## 5. New information architecture

### Tabs (four, single words, same in every orientation)

| Tab | Symbol | Holds |
|---|---|---|
| **Library** | `books.vertical` | Continue, shelves, search, platform chips. Tap a game to open its **Game page**. |
| **Import** | `square.and.arrow.down` | Today's Add screen, unchanged inside: Files, WebDAV, RomM, Multi-Disc, Patch, downloads. |
| **Style** | `paintpalette` | The visual galleries: **Skins**, **Filters**, **App Icon and Colours**, **Library Layout**. |
| **Settings** | `gearshape` | Everything else, with **search** at the top. |

Why a Style tab: the owner's two complaints, "can't find" and "show an image", are both about the visual options. Putting them in one picture-first place answers both. Picking a look is browsing, not configuration.

On iPad and in landscape, keep `LeftRail`. On iOS 18 and later, use `TabView` with `.tabViewStyle(.sidebarAdaptable)` behind `if #available`. Keep the rail on iOS 17.

### Game page (new, depth 1 from Library)

A tap on a cover opens a page. Touch and hold keeps today's context menu as a shortcut, and the tip banner goes away.

- Header: cover, title, platform, play time, last played, and a big **Play** button with **Resume** when an auto state exists.
- Picture rows, each opening today's sheet: **Skin** (thumbnail of the chosen skin), **Filter** (live preview tile), **Core** (core name plus option count), **Save States** (strip of the latest 3 screenshots), **Cheats** (count), **Controls for this game**, **Play Nearby**.
- Footer: Edit Details, Delete (destructive, with today's confirm sheet).

### Settings (new categories, each with an icon tile)

| Category | Contains (moved from) |
|---|---|
| **Profile** | Player Name (new), Game Center status, RetroAchievements (from Play) |
| **Gameplay** | Quick Start, Auto Save State, Rewind, Auto Full Screen, Respect Silent Mode, play time stats (from Play) |
| **Controllers** | Connected controllers and player slots (from the sort menu), Controller Mapping, Macros, Turbo, Rumble, Haptics, Hide Touch, Skin Sound Effects (from Controls) |
| **Screen** | Default scaling and dual-screen layouts, AirPlay Full Screen (from Graphics) |
| **Systems** | BIOS Files (from Library), default core per platform (from Library), Core Options (Cores) |
| **Library** | Cover Art, Refresh Covers, game count |
| **Storage and Sync** | iCloud Sync, game file size, Clear Cache |
| **Help** | Guides (from About), About, Licences, Share, version |
| Gaga Plus | Unchanged, only while the paywall gate is open |

Skins, Filters, App Icon, Appearance, Accent and Library Layout move to the **Style** tab. Settings keeps one row per moved item, "Skins: in Style", so old habits still land somewhere.

### Global settings search

- `.searchable(text:prompt:)` on the Settings tab, with the prompt "Search settings, like skin or BIOS".
- Index: one static `[SettingEntry]` array with `title`, `keywords`, `category`, `symbol` and `destination`, for example `"Skins", ["skin","touch","layout","buttons","controller look"], .style`. Keep it next to `SettingsView`. A unit test checks that every category is reachable and that "skin", "bios", "filter", "shader", "cheat", "username" and "icloud" each return at least one entry.
- Scopes: All, This Game (only while a game is paused), App. Recent searches are kept in `@AppStorage`, limited to 5.
- Results are picture rows (section 6). Picking one opens the destination and briefly highlights the row. The highlight is skipped when Reduce Motion is on.
- The pause menu gets the same search, scoped to This Game.

### Pause menu

- A two-column grid of picture tiles. In landscape it is a side panel on the trailing edge, so the game stays visible.
- Order: Resume, Save State, Load State (shows the latest state picture), Fast Forward (speed), Filter, Skin, Screen, Controls, Cheats, Core Options, Achievements, Record Macro, Quit.
- Quick Slot stays as a stepper under Save State.

## 6. Visual system: every option shows an image

Rule: every navigable row and every picker choice has a 56 by 56 pt tile on the leading edge (40 pt in compact height). All images are made by the app at runtime from its own renderer, symbols and tokens. No bitmap is copied from another app or site. Every tile has an `accessibilityLabel`. A purely decorative tile is `accessibilityHidden(true)`, and the row text then carries the meaning.

| Option type | Image | How it is built (existing code) | Alt text pattern |
|---|---|---|---|
| Filter or shader | **Live preview** of the current frame, or the built-in test picture, through that filter | `FilterPickerView` preview path. Add a small cached `ShaderManager` render per filter, kept as `UIImage` in the cache directory. | "Filter preview: {name}" |
| Skin | **Rendered skin** in the current orientation | `SkinThumbnail` (`AssignSkinView.swift:4`) scaled into the tile. Imported skins use their own image. | "{system} skin: {name}, {orientation}" |
| Skin layout preset | Line diagram | Existing layout cards in `AssignSkinView` | Existing description text |
| Screen scaling (Fit, Fill, Integer, Stretch) | A paper frame with an ink rectangle drawn at that scale | `Canvas`, about 20 lines per mode | "Scaling: {mode}, {one-line effect}" |
| Dual-screen layout | Two rectangles in the preset arrangement | Same drawing as `ScreenLayoutEditorView` at small scale | "Layout: {preset}" |
| Toggle (on/off) | An illustrated tile that shows the effect, drawn with SF Symbols and tokens. Examples: Rewind uses `backward.fill` over a frame strip; Auto Save State uses `square.and.arrow.down` over a cover; Rumble uses `iphone.radiowaves.left.and.right`; Respect Silent Mode uses `bell.slash`. The tile dims when the toggle is off. | `Image(systemName:)` in a `surface` rounded square, `accent` glyph | "{setting}, {on/off}" comes from the Toggle itself, so the tile is hidden |
| Picker (Appearance, Sort, Haptics level) | One mini tile per choice. Appearance shows paper vs ink swatches. Haptics shows one, two or three wave rings. | Inline `Picker` with a `.menu` label that holds the tile | "{choice}" |
| App icon | Existing icon previews | `AppIconPicker` (`DisplayPane.swift:4`) | Existing |
| Accent colour | A swatch on a mini cover | `AppTheme` tokens | "Accent: {name}" |
| Library layout (per row, cover style, corner, square) | A mini shelf drawn at the chosen setting | `Canvas` that reuses `LibraryDisplay` values | "Shelf preview: {n} per row, {style}" |
| Core | Platform spine colour plus the core name in `meta` text | `AppTheme.spine(_:)` | "{core} for {platform}" |
| BIOS file | File glyph with a status mark (check, missing, optional) | SF Symbols `doc.fill` plus `checkmark.circle` or `exclamationmark.circle` | "{file}: found / missing / optional" |
| Save state | The state's own screenshot | `ManageSavesSheet` already stores pictures | "Save state {slot}, {date}" |
| Account rows (Profile, RetroAchievements, iCloud) | Initial monogram or service symbol | `person.crop.circle`, `trophy`, `icloud` | "{service}: {status}" |
| Settings category | 32 pt symbol tile in the category bar | One SF Symbol per category | Category name |

One shared component holds this: `OptionTile(kind:)` in `Sources/UI/OptionTile.swift`, with a `PictureRow(title:value:tile:action:)` wrapper. `ActionRow`, `ToggleRow` and `ValueRow` gain an optional `tile:` parameter, so panes change row by row.

Accessibility rules:

- Tiles scale with `@ScaledMetric`.
- At accessibility text sizes the row stacks the tile above the text instead of shrinking the text.
- Live previews pause and show a still frame when Reduce Motion or Low Power Mode is on.
- Glyphs on tiles use `accent` on `surface` (5.09 light, 5.35 dark). This pair already passes the AA test.
- Footnotes shrink to one line, and the full text moves into an info button (`info.circle`, opens a popover). VoiceOver reads the full note as the row hint.

## 7. Per-screen changes

| Screen | Change |
|---|---|
| Library | Tap opens the Game page. Remove the tip banner after the first launch. Search moves into the navigation bar (`.searchable`), so it is never cut off. Sort stays a menu, and Controllers leaves it. Landscape: the Continue card becomes a single row strip above the shelves. |
| Game page | New screen, described in section 5. |
| Import | Rename the tab from Add to Import. Each source gets a picture tile (folder, server, RomM monogram, disc stack, patch glyph). |
| Style | New tab with four galleries. Skins: a grid per system with rendered thumbnails, Edit on each one, Import skin. Filters: today's `FilterPickerView`. App Icon and Colours: today's Display pane, top half. Library Layout: today's Display shelf and cover rows, with a live mini shelf. |
| Settings | Search on top. An icon category bar: a horizontal scroll of icon plus one-word label when upright on a phone, and a sidebar list with icons in landscape and on iPad. Picture rows everywhere. Notes go into info popovers. |
| Pause menu | Tile grid. Trailing side panel in landscape. Adds Filter, Skin and Fast Forward speed. Search scoped to This Game. |
| Manage Saves | Screenshot grid instead of a list. Cheats get their own row on the Game page. |
| Controllers | A list of connected pads with each pad's symbol (`gamecontroller`, `playstation.logo` and similar system symbols where they exist), player slot chips, and a test-input glyph that lights when a button is pressed. |

## 8. Implementation order (small, verifiable batches)

Each batch builds, passes `xcodebuild test`, gets a device walk in portrait and landscape (`UITests/GagaEmuWalkTests.swift` `testAuditScreens`, extended), and ships as its own TestFlight build per the usual cadence.

1. **Player name bug.** Section 2 steps 1-7. Verify: unit test, then a DS game shows the player name or "GagaEmu".
2. **Settings search.** Add the `SettingEntry` index, `.searchable` and the result rows (text plus the category symbol for now). Verify: the unit test for the keyword list, and a UI test that types "skin" and reaches Assign Skin.
3. **Rename and regroup Settings categories.** Move rows only, no new views: Profile, Gameplay, Controllers, Screen, Systems, Library, Storage and Sync, Help. Move Controllers out of the sort menu. Verify: walk screenshots and a tap-count table re-run.
4. **`OptionTile` and `PictureRow`.** Start with symbol tiles on every Settings row and category. Verify: VoiceOver rotor pass, AX5 Dynamic Type screenshots, the contrast test.
5. **Style tab.** Move Skins, Filters, App Icon and Colours, and Library Layout into it, reusing the existing views. Add rendered skin thumbnails in the grid. Verify: owner test "change a skin" in 2 taps (Style > Skins > pick).
6. **Live previews.** Cached filter thumbnails, scaling and layout diagrams, the mini shelf. Verify: memory stays flat while scrolling 100+ filters, and Reduce Motion shows stills.
7. **Game page.** Tap opens it. Touch and hold stays. Remove the tip banner. Verify: walk screenshots, and every context-menu action is reachable from the page.
8. **Pause menu tiles.** Grid and side panel, plus Filter, Skin and Fast Forward entries, plus scoped search. Verify: GBA, NDS, PSP and 3DS game walks in both orientations.
9. **iPad sidebar.** `.sidebarAdaptable` on iOS 18 and later, rail kept on iOS 17. Verify: an iPad simulator walk.
10. **Footnote trim.** One-line notes plus info popovers. Verify: AX sizes show at least 5 rows per screen on iPhone.

Target after batch 8: each of the 20 features in section 1 takes 3 taps or fewer, and each is found by search in one query.

## 9. Build status (2026-11-10)

All ten batches are on `main`. `UITests/GagaEmuWalkTests.swift` `testTopFeatureTaps` measures the taps on the iPhone and attaches them as `TAPS`: 52 before, 42 after. No feature takes more taps than before.

| # | Feature | Before | After |
|---|---|---|---|
| 1 | Resume last game | 1 | 1 |
| 2 | Start any game | 2 | 2 |
| 3 | Import from Files | 2 | 2 |
| 4 | Save state | 2 | 2 |
| 5 | Load state | 3 | 2 |
| 6 | Fast forward | 1 | 1 |
| 7 | Change skin, all games | 4 | 2 |
| 8 | Change skin, one game | 3 | 2 |
| 9 | Edit skin layout | 4 | 2 |
| 10 | Default filter | 3 | 3 |
| 11 | Filter, one game | 3 | 2 |
| 12 | Change core | 3 | 2 |
| 13 | Core options | 2 | 2 |
| 14 | Cheats | 3 | 2 |
| 15 | Controller mapping | 3 | 3 |
| 16 | Controller player slots | 2 | 2 |
| 17 | BIOS files | 3 | 3 |
| 18 | RetroAchievements sign-in | 3 | 2 |
| 19 | iCloud Sync | 3 | 3 |
| 20 | Library layout | 2 | 2 |

Where it differs from the plan:

- Settings search is a field above the categories, not `.searchable`, as Settings has no navigation stack. There is no scope bar, and the pause menu's search covers this game only. A result opens its page; it does not highlight the row.
- Library search stays where it was, and the landscape Continue strip is not built.
- Upright on a phone the categories are a sideways strip of icons; in landscape and on iPad they are a sidebar list.
- Cheats on the game page starts the game, since cheats live in the pause menu.
- The new strings have no Spanish translations yet.
- The iPad sidebar (`.sidebarAdaptable`, iOS 18) is built but not run on an iPad.
