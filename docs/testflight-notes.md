# TestFlight notes

Newest first. Each entry is the "What to Test" text for that build.

## 1.0.0 (202611101512), 2026-11-10

New look, easier to find things. Four tabs: Library, Import, Style and Settings.

- Tap a game to open its page: Play or Resume, Start Over, skin, filter, core, save states, cheats and controls. Touch and hold still opens the quick menu.
- Style has Skins, Filters, Icon and Colours, and Library Layout. Every skin picture shows that skin's own buttons, in the way you hold the phone.
- Settings has a search box at the top, and new groups: Profile, Gameplay, Controllers, Screen, Systems, Library, Storage and Sync, and Help. Options show a picture of what they do.
- Player Name is in Settings, Profile. RetroAchievements is there too.
- Each core has its own options page in Settings, Systems, and in a game's pause menu under Core Options. Some options apply at once; others say "Restart to apply".
- The pause menu is a grid of tiles, with Filter and Skin, and a search for this game's options.
- Large text sizes no longer push buttons off the screen.

To test: find a setting with the search box, change a skin in Style, and open a game's page. Tell us anything you could not find.

## 1.0.0 (202611100201), 2026-11-10

New: Cheats now work on more systems. Atari 2600, 5200, 7800 and 8-bit, Atari Lynx, Jaguar, Virtual Boy, Neo Geo Pocket, Dreamcast and Doom have bundled cheats. Commodore 64, Amiga, Pokemon Mini and 3DS take codes you enter yourself. Cheats stay off until you switch them on, and hardcore RetroAchievements still blocks them.

To test: open a game, pause, then Cheats, and switch one on. Tell us which game and cheat if it does nothing. Doom cheats stay on until you reload the game.

## 1.0.0 (202611092335), 2026-11-09

New: iCloud Sync, off by default, in Settings, Storage. It keeps saves and save states the same on your devices, and can include game files. It syncs when you quit a game or leave the app.

If two devices changed the same save, the newest is used and the older stays as a named copy. Deleting a save on one device does not delete it on another.

To test: turn it on on two devices signed in to the same iCloud account, play on one, quit, then open the other.

## 1.0.0 (202611092225), 2026-11-09

New: RetroAchievements. Sign in with your own account in Settings, Play, then earn achievements with toasts and an in-game list. Hardcore mode turns off state loading, cheats and rewind; hardcore approval from RetroAchievements is pending.

## 1.0.0 (202611092051), 2026-11-09

73 new screen filters with live previews, xdelta patches, and about a million built-in cheats.

**Filters**
- 73 new filters in categories such as upscaling, CRT, LCD and handheld, with a search box and a favourites row.
- Each filter shows a live preview, with a before and after view, and its sliders change the picture.
- Set a filter per game or per system.
- Pick a few filters, move the sliders, and check the picture changes in a game.

**Patching**
- Patch a ROM now accepts xdelta and VCDIFF patches.
- Apply one and check the patched game starts.

**Cheats**
- About a million built-in cheats for 18 systems. All are off until you switch them on.
- Open Pause > Cheats in a game, switch one on, and check it takes effect.

## 1.0.0 (202611091303), 2026-11-09

Import cheats from a RetroArch .cht file.

**Cheats**
- Import a RetroArch .cht file from the Cheats screen. Pick the cheats you want; each is added switched off.
- Import a file, switch a cheat on, and check it takes effect in the game.

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
