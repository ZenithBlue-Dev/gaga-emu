# GagaEmu Design System: Paper and Ink

This describes the design as implemented. Tokens and shared components live in `Sources/App/AppTheme.swift` (`Palette`, `AppTheme`). The screen specifications are in `docs/06` section 3. If this file and the code disagree, the code is right and this file needs fixing.

The UI is an original design: a quiet game shelf, flat and print-like, on warm paper with ink and one vermilion accent. Manic EMU is a feature reference only (`docs/02`). Its UI, labels and layouts are never copied.

## Colour

All tokens follow the system appearance. There is no theme or appearance setting.

| Token | Light | Dark | Use |
|---|---|---|---|
| `paper` | `#F4EFE6` | `#16140F` | Screen background |
| `surface` | `#FBF8F2` | `#211E18` | Rail, cover placeholders |
| `ink` | `#1C1A17` | `#EDE6D8` | Text |
| `muted` | `#6B655B` | `#A79F90` | Secondary text and glyphs |
| `rule` | `#D9D1C2` | `#3A352C` | Hairlines, disabled button fill |
| `accent` | `#BF3D18` | `#F0683F` | Accent text and glyphs. Vermilion adjusted for AA. |
| `accentFill` | `#E4572E` | `#E4572E` | True vermilion, only as a fill under `onAccent` |
| `onAccent` | `#1C1A17` | `#1C1A17` | Text on `accentFill` |
| `letterbox` | `#1C1A17` | `#1C1A17` | Around the game picture, in both appearances |
| `onLetterbox` | `#EDE6D8` | `#EDE6D8` | Touch controls and text on the letterbox |

Covers also carry a spine colour from `AppTheme.spine(_:)`: one hue per catalog platform at saturation 0.6 and brightness 0.7. The platform code text is the non-colour cue, so the hue never carries meaning alone.

### Contrast

Calculated with the WCAG formula from the token values. `testPaletteTextMeetsAA` in `Tests/GagaEmuTests.swift` asserts at least 4.5:1 for the text pairs and `onAccent`.

| Text | On | Light | Dark |
|---|---|---|---|
| `ink` | `paper` | 15.16 | 14.82 |
| `ink` | `surface` | 16.38 | 13.38 |
| `muted` | `paper` | 5.04 | 7.02 |
| `muted` | `surface` | 5.45 | 6.34 |
| `accent` | `paper` | 4.71 | 5.92 |
| `accent` | `surface` | 5.09 | 5.35 |
| `onAccent` | `accentFill` | 4.71 | 4.71 |
| `onLetterbox` | `letterbox` | 13.98 | 13.98 |

Two pairs sit under 4.5 on purpose. `rule` on `paper` is 1.32 (light) and 1.51 (dark), because a hairline is decoration and never the only cue. Disabled button text, `muted` on `rule`, is 3.81 (light) and 4.64 (dark); WCAG exempts disabled controls.

`accent` passes on `paper` and `surface` only. `accentFill` is not a text colour. Check a new pair before using it.

## Type

| Style | Definition | Use |
|---|---|---|
| `Font.screenTitle` | `.title2`, New York (`.serif`), semibold | Screen and sheet titles |
| `Font.gameTitle` | `.title3`, New York, semibold | Large game titles |
| `Font.meta` | `.caption`, monospaced | Platform code, play time, file size |
| System default | SF Pro text styles | Body text and controls |

All text uses Dynamic Type text styles. Columns scroll, so larger sizes do not clip. The rail is the one exception: it caps at `xxLarge`, keeps its width and offers the large content viewer. Touch control labels may shrink to fit (`minimumScaleFactor(0.6)`), because their pads have a fixed size.

## Spacing

There is no spacing scale type. Code uses these values, and new layouts should keep to them:

- Stack spacing: 0, 2, 4, 8, 12, 16. Occasionally 6 or 20.
- Padding: 16 for most panels and 20 for sheet content and sheet headers. Vertical row padding is 6, 8 or 12.

## Shape and surface

- Corners are `AppTheme.corner`, 6pt. Do not go larger.
- `Rule` is the separator: a hairline in place of shadows and cards. It follows its stack's axis.
- The codebase has no `.shadow`, gradient, blur or material. Keep it so.
- System controls such as context menus and confirmation dialogs keep the look iOS gives them.
- The app icon is the one exception to flatness. It is an object on the Home Screen, not part of the UI (`docs/BRAND.md`).

## Motion

One animation: `.easeOut(duration: 0.15)`, a fade, in `RootView` between screens and in `GameView` for the pause menu. Both are removed under Reduce Motion. Do not add movement, spring or parallax.

## Components

| Component | Where | Notes |
|---|---|---|
| `PrimaryButtonStyle` | `AppTheme.swift` | `accentFill` under `onAccent`, `.headline`, min height 44, full width. Disabled uses `rule` and `muted`. Pressed is 0.7 opacity. |
| `QuietButtonStyle` | `AppTheme.swift` | `accent` text, min height 44, full-size hit shape |
| `PaperSheet` | `AppTheme.swift` | Header for every sheet: title, optional `meta` subtitle, Close, then a `Rule`. Sheet corner is 6pt. |
| `Rule` | `AppTheme.swift` | The hairline |
| `LeftRail` | `Sources/UI/RootView.swift` | 72pt wide on `surface`. Items are at least 56pt high. Selected uses `accent`, bold text, a heavier glyph and a 3pt bar. |
| `CoverArt` | `Sources/UI/Games/CoverArt.swift` | 3:4, 6pt corners, 1pt `rule` outline, 3pt spine on the left. Without art, a serif initial and the platform code. With Cover Art on, the cached box art fills the tile. |
| Filter chips, search | `Sources/UI/Games/LibraryView.swift` | One compact row. The visible chip is 30pt and the search field 34pt, inside a 44pt row. |
| Touch controls | `Sources/UI/Game/GameView.swift` | Outlined in `onLetterbox`, filled with `accentFill` while held. Hit areas are at least 44pt. A toggle that is on (Fast Forward, Mute, Turbo toggle, a running macro) stays filled and adds "On" to its label, so colour is not the only cue. A stick is a ring with a knob that follows the finger. |

## Landscape and upright layouts

The app runs upright and in landscape (`docs/06` section 3): iPhone upright, landscape left and right; iPad in all four orientations. A game can lock its orientation (Auto, Upright or Landscape) from its Controls sheet. `compact` below means a compact vertical size class, a landscape phone. "Upright" means a phone held upright: compact width, regular height.

| Screen | Layout | Sizes |
|---|---|---|
| Root | Rail, rule, content | Rail 72pt |
| Library | Continue panel on the left, chips and shelves on the right | Panel 27% of the Library width, 200pt to 300pt compact, else 220pt to 300pt. Search 20%, 130pt to 260pt (`LibraryMetrics`). Panel cover 84pt or 150pt wide. Shelf cover 120pt or 140pt wide, times the tile scale up to 1.8. |
| Add | Two columns: Choose from Files and drop target, then the other sources and the legal notice. A landscape phone has a compact width too, so only upright stacks them. | Choose from Files is 72pt high |
| Settings | Two panes: categories, then the selected category | Only working rows appear |
| Filter picker | List on the left, live preview and its controls on the right | List 240pt compact, else 320pt. Controls 190pt compact, else 240pt: Upscale chips in two columns, sliders, Reset. |
| Game | Picture aspect fit on `letterbox`, a touch band on each side | Pause side sheet 280pt |

Upright on a phone:

| Screen | Layout |
|---|---|
| Root | Content, rule, then the rail as a bar along the bottom |
| Library | Continue panel above the chips and shelves, at most 200pt high |
| Add | The two columns stack |
| Settings | Categories scroll sideways along the top, the selected category fills the width below |
| Assign Skin | Layout drawings scroll sideways |
| Game | Picture in the top half, sized by the scaling mode. Touch controls in the lower half. Two-screen systems start Stacked. Screen settings are kept per orientation. |
| Layout editor | The canvas takes the edited orientation's shape; the panel sits where the picture goes |

Turning the device mid-game re-lays the view only. The core keeps running, and the picture views resize their drawables.

iPhone height in landscape is about 375 to 440pt, so persistent chrome stays small and nothing sits above or below content that does not need to.

## Safe areas

Backgrounds extend under the notch, Dynamic Island and home indicator. Content stays inside the safe area on whichever side the hardware sits, because landscape left and right put it on opposite sides. Check both, and upright. The game view hides the status bar and home indicator.

The Library's shelf column (tip, chips and search, rules, shelves) runs under the side safe areas, so its rules reach the edge and covers scroll through the notch band. Its gutters are 16pt plus the side inset, so at rest nothing sits under the notch. The rail and Continue panel stay inside the safe area.

## Accessibility

- Icon-only and cover controls have VoiceOver labels. Every touch control has one, and activating it presses that button briefly.
- Targets are at least 44pt.
- Selected states also change weight, shape or glyph. Colour is never the only cue.
- New colour pairs meet AA and go into `testPaletteTextMeetsAA`.
- Motion respects Reduce Motion.

## Do

- Use `AppTheme` tokens and the styles above.
- Use hairlines and whitespace for structure.
- Use New York for titles only, and monospaced for metadata only.
- Show only rows and controls that work today.
- Pair every platform colour with its code text.

## Do not

- Add shadows, gradients, glass, blur, cards or a floating tab bar to the UI.
- Add a mascot, RPG flavour, avatars or a profile card.
- Hard-code a colour or corner radius in a view.
- Use a second accent colour. Vermilion is the only one, and spine hues are data.
- Put `accentFill` behind white or use it as text.
- Copy Manic EMU's or any other app's screens, labels or layouts.
