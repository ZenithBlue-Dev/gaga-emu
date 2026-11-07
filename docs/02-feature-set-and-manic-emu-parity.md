# 02 — Feature Set & Manic EMU Reference

Manic EMU is a feature reference only: this document tracks which features exist. The UI is not copied, and nothing here is an instruction to match Manic's screens, labels or layouts. GagaEmu's own original design is in `docs/06` section 3. Feature facts are checked against the 14 screenshots in `maniac-emu-reference-images/`. GagaEmu does not claim 1:1 parity: some Manic features are deliberately dropped, Manic's listing covers more systems than GagaEmu plans, and much of the detail below is GagaEmu's own design.

No screenshot shows a version number. The [App Store listing](https://apps.apple.com/us/app/manic-emu/id6743335790) showed version 2.0.2 when checked on 2026-11-07.

## Legend

**Source of each fact**

| Tag | Meaning |
| :--- | :--- |
| **[S]** | Seen in screenshot |
| **[L]** | App Store listing or public repo |
| **[G]** | GagaEmu design. Not evidence of what Manic EMU does. |

**Status in this repo**

| Status | Meaning |
| :--- | :--- |
| **built** | Code exists in `Sources/`. Nothing has run against a real core, because the app today is a shell plus a mock core. |
| **stub** | A UI row, setting or registry entry exists with no working behaviour behind it. |
| **planned** | Not in the code yet. |

Status reflects a code read, not a device test. `docs/07` is canonical for phases and status.

---

## 1. Screenshot Index

| Screenshot | Screen | What it shows [S] |
| :--- | :--- | :--- |
| `026FA2CF` | Controllers side panel | `Touch Control` row, `Player 1` picker, help and more buttons, empty-state art |
| `0596EA12` | Paywall | Five feature cards, three plans, `Redeem Offer`, `Restore Purchases`, `Subscribe Now`, trial/cancel text, legal links |
| `0BF2D032` | Shaders sheet | Search, four tabs, preview card, seven presets on the Default tab |
| `3D38E22D`, `DE9D26E2` | Emulator Core sheet | Platform-to-current-core rows, long-press caption |
| `443B8BE2` | iOS system document picker | Reached from Files import. Recents, Shared and Browse tabs. The filenames are the device owner's files, not app features. |
| `44F4AEE0`, `C4E3779B` | Settings: General, Advanced | Rows listed in section 2.7 |
| `8A17681E`, `9EFF77AC` | Settings: Support, Others, More from Manic | Rows listed in section 2.7 |
| `A59F001A` | Import tab | Six import routes, top-bar buttons, mascot art |
| `E2946B38` | Play History side panel | Empty state only: `No Play History`, `Import Games` |
| `F7ADD189` | Settings top | Membership banner, Adventurer Card, start of General |
| `FC11608F` | Games tab, empty | Welcome text, import hint, Discord pill, ROM legal notice, three-tab bar |

---

## 2. Subsystem Specifications

### 2.1 Adventurer Card & Community Links (Ref: `F7ADD189`, `8A17681E`)
- **Card** [S]: heading `Adventurer Card`, with `Nickname: Adventurer`, `Play Time: Start your adventure now`, `Joined: 6 Nov 2026` and a mascot image. Status: removed by the redesign; saved fields stay in `state.json`.
- **Banner** [S]: `Unlock MANIC EMU membership`, `You are the protagonist of this story`, `50% Off`. Status: not built. GagaEmu has a Gaga Plus settings category instead.
- **Play time** [G]: tracked per game and totalled in Settings > Play. Status: built.
- **Community links** [S]: `FAQ`, `Feedback`, `Join QQ Channel`, `Join Discord`. Status: `FAQ` and `Feedback` built as links; `Join QQ Channel` and `Join Discord` removed, since GagaEmu has neither (`docs/06` section 3.3).
- **Clear Cache** [S]: label only. What it clears (temp ROMs, covers, shader caches) is [G].

### 2.2 Controllers & Input (Ref: `026FA2CF`, `C4E3779B`)
- **Controllers panel** [S]: a side panel that slides in with the main screen visible at its edge, opened from the top-left button on Games. It has a `Touch Control` row with a `Player 1` picker, plus `?` and `...` buttons. Status: slot assignment built, in Settings > Controls.
- **Player slots**: only `Player 1` is seen [S]. Players 1 to 4 and touch fallback are [G]. Status: built in `Sources/Input/ControllerManager.swift`.
- **Hardware controllers** [G]: `GameController.framework` for DualShock 4, DualSense, Xbox, Joy-Con and MFi pads. Brands are not shown in any screenshot.
- **Keyboard input** [G]: Bluetooth keyboard and Mac input for DOSBox Pure, EKA2L1 and J2meJS. Status: built. Other cores read it as pad buttons through `ControllerManager.KeyMap`; DOSBox Pure gets every key (bridge ABI 5 `GagaInputState.keys`, `docs/06` section 2.5).
- **Rumble** [S]: subtitle `The device vibrates during certain events`. Mapping core vibration events to CoreHaptics is [G]. Status: the row is built as a haptic on each touch press. Core vibration events need a bridge addition and are not planned yet.
- **Skin Sound Effects** [S]: toggle, shown on. The sound design is [G]. Status: built, a system click on each touch press.
- **Respect Silent Mode** [S]: subtitle says audio plays only when not in silent mode. Status: built, not yet tested on a device.
- **TriggerPro** [S]: subtitle `Create and manage advanced custom buttons.` Nothing more is shown. Turbo at 5 to 30 Hz, hold latch and combos of up to four steps are [G]. Status: built in `Sources/Input/TriggerProManager.swift`.
- **Skins**: `Assign Skin` [S], and skins import through Files [S]. `.deltaskin` and Flex formats are [G]; compatibility with Manic's Flex skins is unverified. Loader status: built in `Sources/Input/TouchSkinEngine.swift`. `Assign Skin` is built (3.9): three original touch layouts, per platform or per game. A skin customizer is planned.

### 2.3 Shaders (Ref: `0BF2D032`)
- **Sheet** [S]: search field (placeholder `SearchShaders`), edit button, close button, an image button on the preview card (purpose not shown), and an eye icon plus radio button on each row. Status: GagaEmu has a list and a large live preview only (`docs/06` section 3.4).
- **Preview**: the card shows a pixel-art scene [S]. A still cannot show whether it is live. Live preview is [G]. Status: built.
- **Tabs** [S]: `Default`, `RetroArch`, `Import`, `Custom`. Only Default's contents are shown. GagaEmu has no tabs; its list has sections instead (`docs/06` section 3.4).
  1. **Default**: MSL presets [G]. Status: built.
  2. **Community** (in place of the RetroArch tab): public-domain libretro Slang shaders converted ahead of time [G], with licences recorded in `docs/05` section 5. Status: built, three presets.
  3. **Import**: runtime `.metal` source through `makeLibrary(source:)` [G]. Status: built. `.slangp` import needs a translation path and is deferred to after MoltenVK (`docs/07` 3.6). Status: planned.
  4. **Custom**: parameter editing such as scanlines, curvature, bloom and colour temperature [G]. Status: built as sliders saved per filter; saved custom presets are planned.
- **Presets** [S]: `Original`, `Cartoon`, `CRT v1`, `CRT v2`, `Geom CRT Border`, `Geom CRT`, `Film`. The screenshot cuts off at Film, so the total is not confirmed. Effect definitions are [G]; see `docs/05`.
- **Anime4K, xBRZ and CRT-Royale**: Anime4K is built from its MIT-licensed shaders and is premium. xBRZ and CRT-Royale are GPL and do not ship; GagaEmu's own Edge Smooth upscaler and CRT Deluxe preset replace them, and a saved `crt-royale` choice falls back to Original.

### 2.4 Import Hub (Ref: `A59F001A`, `443B8BE2`)
- **Top bar** [S]: `+`, cloud-download, `?` and `...` buttons, with tagline `Your adventure begins here!`. Their functions are not shown. Status: not specified.
- **Files** [S]: `Import games, skins, game saves from files or iCloud`. Opens the iOS document picker. Only `.zip`, `.7z` and generic document files are visible there. Other formats (`.rar`, `.bin`, `.iso`, `.chd`, `.pbp`, `.cso`) are [G]. Status: built.
- **WiFi** [S]: toggle, `Transfer files via browser on same network`, shown off. Status: built in `Sources/Hub/WiFiTransferServer.swift`.
  - **Safeguards** [G]: off by default, a new 4-digit PIN each session, and port 8080.
  - `NSLocalNetworkUsageDescription` is set in `Info.plist` because iOS requires it for local network access.
- **Read Clipboard** [S]: `Supports files copied from macOS or Files app`. Status: built in `Sources/Hub/ClipboardImporter.swift`.
  - Reads the clipboard only when the user taps the button [G].
  - Accepting http(s) download links and raw ROM data is [G]; neither is shown for Manic.
- **MultiDisc Helper** [S]: title only. Grouping by disc naming and writing `.m3u` playlists is [G]. Status: built.
- **RomPatcher** [S]: title only. In-memory IPS, UPS and BPS patching with checksum verification is [G]. Status: built.
- **Drag & Drop** [S]: `Drag files to any Manic EMU interface for transfer`, so the target is any screen, not only the game grid. Status: built on the Add screen only.

### 2.5 Library & Gameplay (Ref: `FC11608F`, `E2946B38`, `44F4AEE0`)
- **Navigation** [S]: bottom bar with `Games` (rocket), `Import` (folder), `Settings` (gear). The Games header has a controller button on the left and a crossed-swords button on the right, which opens the Play History side panel.
- **Empty state** [S]: `Welcome to MANIC EMU's World`, `Tap the [icon] button to import` (a text hint, not a button), `Join Discord for assistance`, `Ensure game ROMs are legally obtained`. There is no hero art here; the mascot art is on Import.
- **Play History** [S]: the empty state only, with an `Import Games` button. GagaEmu's play history is the Continue panel plus a Recent filter [G]. Status: built.
- **Library** [G]: search, platform filter and favourites. Console ordering (`Console Ordering` appears as a Theme subtitle [S]) is not planned. No populated library appears in any screenshot. Search is not visible on Manic's empty Games header.
- **Long-press** [S for core switching only]: a caption says cores switch by long-pressing a game. Other sheet actions are [G]; see `docs/06` section 3.1.
- **Cover Scraping** [S]: row only. GagaEmu's row is `Cover Art` in Settings > Library, off by default. The source is [G]: Libretro Thumbnails by exact title; OpenVGDB and SteamGridDB are not used. Status: built (3.8).
- **Save states**: `Auto Save States` is a toggle, shown off [S]. Manual slots with thumbnails and a proposed 50-slot rolling auto-save are [G]. Status: the toggle is hidden until 2.6, and the free-tier cap exists in `StoreKitManager` but has no caller.
- **iCloud Sync** [S]: shows `iCloud Not Enabled`. Sync across devices is [G]. Status: blocked on the App ID's iCloud capability, row hidden (3.11).
- **Other enhancements** [G], status planned: rewind on qualifying cores, RetroAchievements Softcore and Hardcore (the row is [S], status blocked on an owner account and approval, row hidden), AirPlay Fullscreen (the toggle is [S], greyed off; GagaEmu's version is built but unverified on a second screen, row hidden).

### 2.6 Premium & StoreKit 2 (Ref: `0596EA12`)
`docs/06` is canonical for this spec. This section is a summary.

**Seen in screenshot** [S]:
- Heading `Unlock Premium Features`, with five feature cards: a speed card clipped to `Speed`, `Unlimited Save States`, `Unlimited Cheat Codes`, `Premium Filters`, `Auto Save State`.
- `Annual Membership` ₹499/year (₹41.58/month) with `50% Off`.
- `Monthly Membership` ₹99/month with `Introductory Offer`.
- `Lifetime Pass · One-time Payment` ₹999 (struck ₹1998) with `Best Value`.
- `No charges during trial period. Cancel anytime`, `Subscribe Now`, `Redeem Offer`, `Restore Purchases`, Terms of Service and Privacy Policy links.

**App Store listing** [L]: US prices are $0.99 monthly, $4.99 annual and $9.99 for a lifetime plan named `Forever Access`. The description also names extra controller players as premium. GagaEmu does not copy that gate.

**GagaEmu policy** [G]:
1. **Emulation stays free**: every core, ROM import, saves, baseline shaders and local multi-controller play. No core or platform is ever gated.
2. **Premium is five items**: higher fast-forward speed, unlimited save states, unlimited cheat codes, premium filters and auto save state.
3. **Sell only what works**: only filters that run on core frames are premium; `crt-royale` is not shipped and CRT Deluxe replaces it (`docs/07` 3.4). Premium Filters cover only cores whose frames pass through the host shader chain (`docs/06` section 4.3). Netplay is not gated or promised until built.
4. **Paywall contents**: Restore Purchases, Redeem Offer, Terms and Privacy links, and trial/cancel disclosure. Prices come from `Product.displayPrice` and are never hard-coded. Lifetime owners never see subscribe prompts. Entitlement comes from StoreKit 2 `Transaction.currentEntitlements`.
5. **Release gate**: the paywall stays off in submitted builds until a real core runs end to end. App Store metadata must be corrected before submission, because it currently describes gameplay that does not exist.

**Limits as they exist in `Sources/Store/StoreKitManager.swift`** (GagaEmu policy, not Manic fact):

| Item | Free | Premium | Note |
| :--- | :--- | :--- | :--- |
| Save states | 3 | Unlimited | Lines 37, 109 |
| Cheat codes | 3 | Unlimited | Lines 38, 110 |
| Fast-forward | 2x | 5x | Line 39. 5x is unconfirmed in screenshots. |
| Premium Filters | Locked | Unlocked | `premiumShaderIDs` lists `geom-crt`, `geom-crt-border`, `crt-deluxe` and `anime4k`. No Manic screenshot shows which filters are premium. |
| Auto save state | Not gated | Not gated | No entitlement exists yet. Adding it is a roadmap item. |

**Products** (IDs unchanged): `monthly.sub`, `annual.sub` and `lifetime.pass`. GagaEmu's labels are in `docs/06` section 4.1.

### 2.7 Settings Row Inventory
Rows and subtitles are [S] and describe Manic's screen. GagaEmu's labels and layout are in `docs/06` section 3.3. Status comes from `Sources/UI/Settings/SettingsView.swift`.

| Section | Row | Source detail | Status |
| :--- | :--- | :--- | :--- |
| General | `Appearance` | Shown `Dark Mode`; three unlabelled icons | not planned: the app follows the system appearance |
| General | `Theme` | `App Icons, Theme Colors, Boxart Settings, Console Ordering` | not planned: the palette is fixed |
| General | `Quick Start` | `Skip preparation page`; shown off | built: GagaEmu has no preparation page, so it opens the most recent game when the app starts |
| General | `Auto Save States` | Shown off | hidden |
| General | `Assign Skin` | | built, in Controls |
| General | `Cover Scraping` | | built as `Cover Art`, in Library, off by default |
| Advanced | `AirPlay Fullscreen` | `Enable fullscreen mirroring`; greyed off | hidden: built, not verified on a second screen |
| Advanced | `iCloud Sync` | `iCloud Not Enabled` | hidden: blocked on the App ID capability |
| Advanced | `Auto Full Screen` | Enters full screen when a controller connects; shown on | built |
| Advanced | `BIOS` | `BIOS required for some platforms` | built |
| Advanced | `Respect Silent Mode` | Shown off | built |
| Advanced | `Online Play Settings` | | hidden |
| Advanced | `Rumble` | Shown off | built: haptic on touch presses only |
| Advanced | `Skin Sound Effects` | Shown on | built |
| Advanced | `RetroAchievements` | | hidden: blocked on an owner account and approval |
| Advanced | `TriggerPro` | `Create and manage advanced custom buttons.` | built |
| Advanced | `JIT` | Between TriggerPro and Shaders | **Deliberately dropped.** No JIT in any shipped core. |
| Advanced | `Shaders` | | built |
| Advanced | `Emulator Core` | | built |
| Support | `FAQ`, `Feedback` | | built as links |
| Support | `Join QQ Channel`, `Join Discord` | | removed; see `docs/06` section 3.3 |
| Others | `About Us`, `Share Manic EMU` (as `Share GagaEmu`) | | hidden |
| Others | `Clear Cache` | | built |
| Others | `Reset Tips` | `Show previously dismissed alerts and tips again` | hidden |
| Others | `Language` | Shown `English` | hidden |
| Others | `Terms of Service`, `Privacy Policy` | | built as links |
| Others | `Featured Items` | Purpose not shown | removed |
| More from Manic | BitBop promo, `Try Now` | Manic's own product | **Not applicable.** Not planned. |
| None | `Rate Us` card | `Your 5-star rating means the world to us! :)` | built as a Settings > About row, `Rate GagaEmu`, using the system review prompt, without the 5-star copy |

Rows marked hidden are not shown; each returns in the milestone and settings category listed in `docs/06` section 3.3. Saved values stay in `state.json`.

---

## 3. Platforms

**Emulator Core sheet** [S] (Ref: `3D38E22D`, `DE9D26E2`): the sheet shows only the current core for each platform, so no alternate core is visible. Owner note: one platform can have several cores, and not all appear in the screenshots.

| Platform label | Current core |
| :--- | :--- |
| `Java ME` | `J2meJS` |
| `PlayStation` | `Beetle PSX HW` |
| `Sega Saturn` | `Beetle Saturn` |
| `Mega-CD` | `JGenesis` |
| `Nintendo 3DS` | `Azahar` |
| `Nintendo DS` | `melonDS DS` |
| `Game Boy Advance` | `mGBA` |
| `Game Boy Color` | `Gambatte` |
| `Game Boy` | `Gambatte` |
| `Super Famicom` | `bsnes` |

These are Manic's values, not GagaEmu's defaults. `docs/03` is canonical for GagaEmu's core list, licences and renderers.

**Seen in Manic listing, not planned for v1** [L]: Virtual Boy, Pokémon Mini, Famicom Disk System, Master System, Game Gear, SG-1000, 32X, PC Engine, TurboGrafx-16, TurboGrafx-CD, SuperGrafx, Neo Geo Pocket, Neo Geo Pocket Color, Atari 2600, Atari 5200, Atari 7800, Atari Jaguar, Atari Lynx, Commodore 64, Amiga, DOOM, WonderSwan, Flash.

**Also on Manic's listing, non-shipping research here** [L]: GameCube and Wii. GagaEmu treats them as research and does not promise them.

---

## 4. Not Verified

- Sub-pages of any Settings row, the other shader tabs, a populated library, in-game UI and the long-press menu appear in no screenshot.
- Whether the Emulator Core list continues past `Super Famicom`, and whether the paywall has more cards than the five visible.
- App Store listing details are as fetched on 2026-11-07 and can change.
