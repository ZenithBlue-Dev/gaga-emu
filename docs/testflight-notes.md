# TestFlight notes

Newest first. Each entry is the "What to Test" text for that build.

## 1.0.0 (202611081354), 2026-11-08

This build plays Game Boy Advance games with mGBA. Load a game, then poke at everything below.

**Portrait and landscape**
- Every screen now works in portrait. Turn the phone mid-game and play carries on.
- The Library and Add screens have a fixed landscape layout. Check titles fit and nothing overlaps.

**Screen options**
- Try Fit, Stretch, Whole Pixels, Zoom and Picture Area. Look for blur, cut-off edges and wrong sizes.

**Controls**
- Open the touch layout editor. Move buttons, add app buttons, turbo and macros.
- Remap buttons for a controller type.
- Hold Start to open the menu. Press Home on a controller to open it too.
- Players screen: handles several controllers. A GBA game has one player, so mostly you will see this in the screens.
- Touch haptics: try each strength.
- Skin Style: Device gives a device-shaped skin. Try the colour choices.

**Play tools**
- Rewind: step back a few seconds.
- Filters: save a preset, reload it, import a `.slangp` file.
- Cheats: add, switch on and off.
- Rumble: games that shake should shake your pad or phone.
- Game Mode: check play feels steady and the phone stays calm.

**Library**
- Cover art: fuzzy matching and Refresh Covers. It is off by default. Turn it on under Settings > Library.
- Drag and drop a game file onto the app.
- About Us, Share and Reset Tips.

**Known limits**
- Only the GBA core is in TestFlight builds for now.
- Play Nearby needs two phones and a system that supports it, so it is not available for GBA.
- Device skins are fixed layouts.

## Earlier

### 202611080925
- Game Mode.
- mGBA.
