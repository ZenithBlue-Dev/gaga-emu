# Installing the GagaEmu JIT build

The JIT build (`GagaEmu-JIT-<version>.ipa`) is for sideloading onto your own device only. It is the
`DevJIT` configuration with the personal core set (`GAGA_CORE_SET=sideload`): every core, StoreKit and
the paywall compiled out, and a JIT recompiler in 10 cores. TestFlight and App Store builds never contain
JIT: `scripts/nojit-gate.sh` refuses any build except a non-archive `DevJIT` build that holds a JIT core
or the JIT option.

JIT makes some systems much faster. Without a debugger serving JIT memory, every game still runs, on
the interpreter, as in the App Store build. No games or BIOS files are included. Use your own dumps.

## Which cores use JIT

| Core | System | What is recompiled |
|---|---|---|
| PPSSPP (`ppsspp`) | PSP | Allegrex CPU |
| DOSBox Pure (`dosbox_pure`) | DOS | x86 dynamic core |
| melonDS DS (`melonds_ds`) | Nintendo DS | ARM9/ARM7 |
| PCSX-ReARMed (`pcsx_rearmed`) | PlayStation | R3000A dynarec |
| SwanStation (`swanstation`) | PlayStation | R3000A recompiler |
| Beetle PSX HW (`beetle_psx`) | PlayStation | lightrec |
| Mupen64Plus-Next (`mupen64plus_next`) | Nintendo 64 | R4300 dynarec (the RSP stays an interpreter) |
| Flycast (`flycast`) | Dreamcast | SH-4 recompiler (ARM7 and AICA DSP stay interpreters) |
| Azahar (`azahar`) | Nintendo 3DS | Dynarmic for the ARM11 (PICA200 shaders stay interpreted) |
| PicoDrive (`picodrive`) | 32X | SH-2 recompiler |

Every other core is an interpreter in every build.

## What you need

- iOS 26 or later for the StikDebug steps below (see "Older devices" for earlier versions).
- A device passcode and an Apple Account. A free account works.
- A computer (macOS, Windows or Linux) and a USB cable, once, for the first setup.

## Recommended: SideStore + StikDebug (free Apple Account)

### A. One-time setup

1. On the computer, install **iloader** (https://iloader.app). On Windows install iTunes first; on
   Linux install `usbmuxd` first.
2. Connect the device by USB, unlock it and tap **Trust**.
3. In iloader, sign in with your Apple Account, select the device and choose **Install SideStore**.
4. On the device: Settings > General > VPN & Device Management > your Apple Account > **Trust**.
5. Settings > Privacy & Security > **Developer Mode**: turn it on and let the device restart.
6. Install **LocalDevVPN** from the App Store, open it and tap **Connect**.
7. Open SideStore, sign in with the same Apple Account, open **My Apps** and refresh SideStore once.
8. In SideStore add the StikDebug source `https://stikdebug.xyz/index.json` and install
   **StikDebug 3.2 or later**.
9. Give StikDebug a pairing file, one of:
   - on iOS 27: StikDebug > Settings > **Pair a Device**;
   - on the computer: iloader > **Manage Pairing File** > **Place** next to StikDebug.
10. In SideStore, tap `+` in **My Apps** and pick `GagaEmu-JIT-<version>.ipa`.
11. In StikDebug, open the installed-apps list, choose GagaEmu, **Assign Script** > **universal.js**.
    Do this once. GagaEmu is not on StikDebug's automatic script list, so without this step StikDebug
    attaches with no script and GagaEmu stays on the interpreter.

### B. Every time you play with JIT

1. Connect LocalDevVPN (Wi-Fi; on mobile data, connect the VPN and then turn on Airplane Mode).
2. Open StikDebug, tap **Enable JIT** and pick GagaEmu. StikDebug opens the app.
3. Open the game's **Change Core** sheet and turn on **JIT**. The switch is enabled only while a
   debugger is attached. It applies from the next start of that game.
4. Start the game. The core logs `[gaga-core] jit26: JIT engaged`, or the reason it fell back.

If you opened GagaEmu without StikDebug, close it fully and repeat step 2. A game that is already
running when JIT gets enabled stays on the interpreter until you start it again.

### C. Every 7 days (free account)

Connect LocalDevVPN, then SideStore > My Apps > **Refresh All**. If SideStore itself expired, run
iloader on the computer again (A3).

Free-account limits: **3 active sideloaded apps** (SideStore, StikDebug and GagaEmu fill all three;
LocalDevVPN comes from the App Store and does not count) and **10 new App IDs per week**.

## Alternatives

- **AltStore Classic:** free, but AltServer must run on the computer for every 7-day refresh. Then
  follow A4-A6 and A8-A11 for StikDebug.
- **Sideloadly:** free tool on Windows or macOS. Drop the IPA in, sign in, Start. Refresh from
  Sideloadly every 7 days or use its auto-refresh while the computer is on. Then A4-A6 and A8-A11.
- **Paid developer account ($99/year):** sign in to SideStore, Sideloadly or Xcode with it. Apps last
  one year, there is no 3-app limit, and Extended Virtual Addressing and the increased memory limit are
  granted. The JIT steps (B) are the same.
- **Certificate signers (Feather, KSign):** JIT needs `get-task-allow`, which only a development
  certificate gives. Most bought or shared certificates lack it and can be revoked at any time.
- **Not supported on iOS 26/27 TXM devices:** TrollStore (iOS 17.0 at most), JitStreamer-EB, AltJIT,
  and SideStore's built-in JIT. None of them serves per-region JIT memory.

## Entitlements

The IPA is fake-signed (ad hoc) with these entitlements, so a re-signer can keep them:

- `get-task-allow`: required. StikDebug lists only apps signed with it. Free and paid development
  profiles grant it.
- `com.apple.developer.kernel.increased-memory-limit`: raises the memory ceiling on supported devices.
  Free-account support is community-reported, not documented by Apple.
- `com.apple.developer.kernel.extended-virtual-addressing`: Apple lists it for paid accounts only.
  With a free account the re-signer may drop it. GagaEmu's cores do not need it to run.

iCloud and Game Center entitlements are not in the JIT build.

## How JIT works on iOS 26 and 27 (TXM devices)

On devices with the Trusted Execution Monitor (A15 and later on iOS 26, every device on iOS 27 except a
few iPads), neither `MAP_JIT` nor flipping pages between RW and RX works. A page may run code only if
an attached debugger prepared it. GagaEmu asks for each region with `mov x16, #1; brk #0xf00d`
(`Cores/shared/Jit26.c`), the protocol StikDebug's `universal.js` serves, and writes code through a
second RW mapping of the same pages.

A `brk` with no debugger attached kills the app (SIGTRAP). `CS_DEBUGGED` stays set after a debugger
detaches, so GagaEmu issues the `brk` only when the process also has a live tracer (`P_TRACED`).
Otherwise it logs the reason and uses the interpreter.

## Older devices (before TXM)

On iOS 17-25, or iOS 26 on devices without TXM, attach-and-detach JIT enablers (SideStore's built-in
JIT, AltJIT, StikDebug without a script) set `CS_DEBUGGED` and then detach. GagaEmu does not use that
style: with no tracer left it stays on the interpreter, with no crash. JIT on those devices needs a
debugger that serves the `brk #0xf00d` protocol: StikDebug with `universal.js` assigned (if your
StikDebug version runs scripts on that device), or Xcode with
`command script import <repo>/scripts/jit26_lldb.py` in `~/.lldbinit-Xcode`.

## Pitfalls

| Problem | Fix |
|---|---|
| JIT switch greyed out | No debugger attached. Launch GagaEmu from StikDebug (B2). |
| Log: `CS_DEBUGGED without a tracer` | The debugger detached, or StikDebug ran without a script. Assign `universal.js` (A11) and launch from StikDebug again. |
| Log: `no debugger gave runnable memory` | The debugger does not serve `brk #0xf00d`. Use `universal.js`, not `legacy.js`. |
| Games run on the interpreter though JIT is on | The game started before JIT was enabled. Stop the game and start it again, or close the app fully and launch it from StikDebug. |
| StikDebug heartbeat or connection errors | Connect LocalDevVPN and use Wi-Fi. Re-place the pairing file (A9). |
| StikDebug: Developer Mode is off | Do A5. |
| StikDebug: DDI mount failed | StikDebug > Settings > Redownload DDI, then reboot. |
| Pairing stopped working | You changed or reset the passcode, which invalidates the pairing file. Make a new one (A9). |
| SideStore: maximum number of apps | Remove one sideloaded app, or use a paid account. |
| App will not open after a few days | It expired. Refresh it (C). |
| A large game is killed for memory | Close other apps. The increased memory limit may be missing with a free account. |

**Keep the pairing file private.** It holds device connection credentials: anyone with it can connect
to your device. Never attach it to a bug report.

## Source and licence

GagaEmu is free software under the GNU Affero General Public License 3.0. Bundled cores keep their own
licences; some cores in the JIT build are non-commercial and only allowed in this free personal build.
Source: https://github.com/zenithblue-dev/gaga-emu. Building the JIT build yourself: README, section
"Sideload JIT build".
