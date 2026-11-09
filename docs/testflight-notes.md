# TestFlight notes

Newest first. Each entry is the "What to Test" text for that build.

## 1.0.0 (202611091149), 2026-11-09

Add games from your own RomM server, queue and cancel downloads, make UPS patches, and pick a new app icon.

**Adding games**
- Add games from your own RomM server.
- Downloads from your WebDAV or RomM server now queue, and you can cancel them.
- Start a few downloads, cancel one, and check the rest finish and appear in the Library.

**Patching**
- Patch a ROM can create UPS patches.
- Create one and check it applies to the original file.

**Settings**
- Use your own picture in the filter preview.
- Choose from five new app icons in Settings > Display.

## 1.0.0 (202611091030), 2026-11-09

Add games from your own WebDAV server, import skin layouts, and new Library tools.

**Adding games**
- Add games from your own WebDAV server.
- A guide explains how to reach SMB shares through the Files app.
- Check both paths import a game and it appears in the Library.

**Skins**
- Import button layouts from your own skin files. Positions only, no art.
- Import one and check the buttons land where expected.

**Library**
- Filter the Library by maker.
- Open the Controllers panel from the Library menu.
- Pick discs by hand when you build a playlist.

**Settings**
- Guides are now in Settings > About.
- Spanish and French are available. They are partial and unreviewed, so expect gaps and rough wording.
- Settings > Graphics has an AirPlay Full Screen toggle. Try it with an AirPlay screen.
- The BIOS list splits into Required and Optional.
- Auto Save State has its own toggle.

**Known limits**
- Games and BIOS files are not included. Add your own.

## 1.0.0 (202611090020), 2026-11-09

Settings has a new Display tab, the Library sorts, and ROM patching reads more formats.

**Display**
- Settings > Display: choose Automatic, Light or Dark.
- Pick an accent colour, games per row, shelf titles and cover style, or hide scroll indicators.
- Change each one and check the Library updates.

**Library**
- Sort by title, date added, last played or play time.

**Patching**
- Patch ROMs with PPF, APS and RUP files, as well as the formats already supported.

**Filters and BIOS**
- Search the filter list.
- Import or replace a BIOS from its own row.

**Portrait**
- Every Settings tab now fits in portrait.
- The NDS and 3DS skin editor matches the portrait layout.

**Known limits**
- Games and BIOS files are not included. Add your own.

## 1.0.0 (202611082311), 2026-11-08

Portrait play and menus are fixed. Hold your phone upright and check each screen.

**Portrait layouts**
- Fixed across the app: Library, Add, the filter picker, licences, cheats, the skin and screen editors, and every Settings tab.
- Open each one upright and check nothing is cut off, overlapped or hard to tap.

**Pause menu**
- In portrait the pause menu is a bottom half-sheet. The picture stays visible and the sheet stays clear of the Dynamic Island.

**Two-screen systems**
- NDS and 3DS now fill the full width in portrait. L and R sit in the Select/Start row.

**NES**
- The pause row no longer covers the picture.

**Known limits**
- Games and BIOS files are not included. Add your own.

## 1.0.0 (202611081847), 2026-11-08

SNES is here, and joining a Play Nearby game is more reliable.

**New systems**
- SNES is now included. Load a game and check it starts, shows video, plays sound and takes touch input.
- SNES uses GagaEmu's own sound boot program, so no extra file is needed for sound.

**Play Nearby**
- Fixed joining that could wait forever. If the host does not confirm the code within a minute, you now see a message and can try again.
- Try hosting on one phone and joining on another. Leave the host without confirming and check the joiner stops waiting.

**Known limits**
- Games and BIOS files are not included. Add your own.

## 1.0.0 (202611081709), 2026-11-08

Most cores are now included. Bring your own games and BIOS files, then load a game on each system you own.

**New systems**
- N64, PS1, PSP, Nintendo DS, 3DS, Saturn and Dreamcast.
- Game Boy and Game Boy Color, NES, Mega Drive and Master System.
- PC Engine, WonderSwan, Neo Geo Pocket, Virtual Boy, Lynx, Pokemon Mini and Jaguar.
- Atari systems, Commodore 64, Amiga, DOS, Doom and arcade.
- Check each game starts, shows video, plays sound and takes touch input.

**PSP**
- Loading screens are smoother. Frame duplication is on. Watch for stutter or flicker in loading screens.

**Changes**
- The paste-a-link download is gone. Read Clipboard still imports files.

**Known limits**
- SNES is not in this build.
- Games and BIOS files are not included. Add your own.

## 1.0.0 (202611081435), 2026-11-08

More control options, plus a rotation fix. Load a Game Boy Advance game and try these.

**Keyboard**
- Remap keys for a game or for all games. Try it with a Bluetooth keyboard.
- Keyboard Pass-Through: turn it on and check keys go to the game, not the app.

**Turbo and macros**
- Turbo is now set per player. Switch it on for one player and check the others are not affected.
- Macros: record one, assign it to a button, play it back.

**Multitap**
- A new Multitap setting adds extra player ports. It applies to systems that are not in this build, so a GBA game will not show a change. You only need to see the setting is there and does not break anything.

**Fixes**
- Rotation: turning the phone during play now lays out the touch controls again and the game keeps running. A new test covers this. Turn the phone back and forth a few times, with and without the menu open.
- Hold Start: holding Start to open the menu works again. Check it opens each time and does not open by accident.

**Known limits**
- Only the Game Boy Advance core is in this build.
- Multitap cannot be tried here, because no system in this build uses it.

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
