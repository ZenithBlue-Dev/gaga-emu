# GagaEmu Brand

How GagaEmu names itself, speaks and looks outside the code. The visual system is in `docs/DESIGN.md`.

## Name

The name is **GagaEmu**: one word, capital G and capital E.

The repo is inconsistent today. These need an owner decision and a separate change:

| Where | Current text |
|---|---|
| `Sources/App/Info.plist`, `CFBundleDisplayName` (the Home Screen label) | `GAGA-EMU` |
| App Store name (`AppStore/metadata/en-US/name.txt`) | `GagaEmu - Retro Game Emulator` |
| Settings row, WiFi upload page title, clipboard message, `README.md` heading | `Gaga-Emu` |

**Owner action:** a trademark check on "GagaEmu" has not been done. Do it before release. It should also cover the similarity to other "Gaga" marks.

## What it is

GagaEmu is a multi-system emulator for iPhone and iPad, built for App Store distribution, with no JIT in any shipped core. It plays homebrew and backups the user legally owns. It includes no games, ROMs or BIOS.

## Positioning

A quiet shelf for games you already own. Next to louder emulators, it is calm, honest and made for landscape.

- **For:** people with homebrew or their own dumps, who want one tidy place to play them.
- **Is not:** a game store, a ROM source, or a tool for bypassing copy protection.
- **Says only what is true today.** mGBA is the first real core and has not yet been benchmarked on a device (`README.md`). The subtitle `All-in-One Classic Console Emu` promises more than that, so recheck it before release.

## Voice and copy

Plain, short and calm, like a line printed on a label.

- State facts. "The shelf is empty." is the model.
- Use title case for buttons and actions ("Add Games", "Show All Games") and sentences for everything else.
- Never use exclamation marks, hype, superlatives, emoji, RPG flavour or "you are the hero" language.
- Do not promise performance or that a title will run. The metadata's line is the standard: "We make no promise that any particular title will run."
- Name a real limit when there is one. The WiFi transfer screen says its traffic is unencrypted.
- Say "your games" and "your files". Never imply the app supplies them.

## App icon

**Status: pending owner choice.** The app still ships the placeholder from `scripts/make_app_icon.py`. Sign-off is tracked in `docs/07` milestone 7.6.

All options are in `design/icons/`, with a side-by-side view in `design/icons/options.png`. Each folder has `icon-1024.png`, `icon-1024-dark.png` and `icon-1024-tinted.png`.

| # | Folder | Idea | Weakest point |
|---|---|---|---|
| 1 | `option-1-two-beats` | Two keys, one per syllable of the name | Can read as a die showing two |
| 2 | `option-2-folio` | A play triangle cut from three stacked sheets | Can suggest a video player |
| 3 | `option-3-shelf` | Four spines on a ledge, the app's own Library | Can suggest a book app |
| 4 | `option-4-steps` | Pixel stairs and one pixel in the air: a platform game with no characters | Abstract until you see it as a game |
| 5 | `option-5-well` | Paper cut away and turned step by step, down to vermilion | Weakest at 60pt, says nothing about games |
| 6 | `option-6-phosphor` | One lit pixel on a curved screen, on a vermilion tile | Moves furthest from the paper look; can read as a camera |

Recommendation: option 4. It is the only one that says "game" and "pixels" without borrowing a controller, and its geometry suits the print look.

Rejected: a plus of two crossing planes (reads as medical, and red on white as a flag); a single vermilion dot on paper (reads as a national flag); any pad or cartridge shape.

### Rules

- One glyph, no text, on a tile with a soft top light. The tile's depth is the single allowed departure from the flat UI.
- Supply square, opaque artwork with no alpha. The system applies the corners.
- Do not recolour, outline, add a badge or place the icon on a busy image.
- Where we draw the mask ourselves, use a continuous-corner rounded rectangle at about 22.37% of the side.
- Do not derive the icon from any console, controller, cartridge or other app's icon.

### Format

Use the traditional single-size `AppIcon.appiconset`, with a 1024 PNG and dark and tinted entries. Our depth is rendered into the image, and it fits the existing project and its iOS 17 target. Xcode 27.2's `actool` compiled that set for iOS 17 in a throwaway test.

Icon Composer's layered `.icon` also compiled for iOS 17 in that test, with flat fallback PNGs. It would need the glyph split from the tile and a `project.yml` change, and the system's glass would replace our lighting. Consider it later if the rendered icon looks wrong on iOS 26 or newer. That has not been checked on a device.

### Installing the chosen icon

1. Copy the three PNGs into `Sources/App/Assets.xcassets/AppIcon.appiconset/` and list them in `Contents.json`, using the `luminosity` appearances `dark` and `tinted`.
2. Delete or update `scripts/make_app_icon.py`, because running it overwrites `AppIcon.png`.
3. Update `docs/06` section 3.6 and this section.

To re-render, run `design/icons/render_all.sh`. It needs Blender 5 on the path and uses a fresh factory scene.

## Colour and type summary

Paper `#F4EFE6`, ink `#1C1A17` and one accent, vermilion `#E4572E`. Dark mode uses paper `#16140F` and ink `#EDE6D8`. On paper, vermilion text uses the darker `#BF3D18` to meet AA. New York is for titles, SF Pro for body text and monospaced for metadata. Full tokens and contrast are in `docs/DESIGN.md`.

## Gaga Plus

The paid tier is **Gaga Plus**: two words, both capitalised. Not "Gaga+", "GagaEmu Plus", "Pro" or "membership". Lower-case "premium" may describe its features, and "Premium Filters" is an existing paywall item.

- Emulation stays free: every core, import, saves, baseline filters and local multiplayer. Never imply a core or platform is paid (`docs/06` section 4.2).
- Sell only what works. Do not list a feature that is not built.
- Prices come from the store and are never written into copy or screenshots.
- No urgency, countdowns or fake discounts.

## Screenshots

- Landscape, showing real gameplay in this app's own UI.
- Only homebrew, or test content we have the right to show. No commercial game art, in-game or as covers.
- No console logos, controllers or hardware from a console maker.
- Show only features that work in that build.
- Captions follow the voice rules: short, plain and factual.

**Open problem:** `AppStore/screenshots` must be replaced before submission, because `scripts/make_screenshots.py` builds them from the Manic reference images (`docs/07` milestone 7.6). Do not ship that set.

## Legal rules

Engineering guidance, not legal advice.

- **Trademarks:** use console makers' names and product names in marketing only as factual compatibility, such as a list of supported systems. Never in the app name, subtitle, keywords, icon or as a headline. The current keywords include none.
- **Disclaimer:** keep "GagaEmu is an independent project. It is not affiliated with, endorsed by or sponsored by any console maker. All trademarks belong to their owners." in the store description.
- **Game art:** none, anywhere in marketing.
- **ROMs are the user's own.** The app includes no games, ROMs or BIOS, and does not sell, link to or help anyone obtain them. Say this plainly wherever the app is described.
- **Other apps:** Manic EMU is a feature reference only. Never use its name, images or wording in marketing.
- **Icon artwork:** original, generated by `design/icons/render_icons.py`. Apple's icons were studied but no Apple artwork is in the repo.
- **Core licences:** see `docs/03` for the legal gate. Marketing must not name a core whose licence review is open.
