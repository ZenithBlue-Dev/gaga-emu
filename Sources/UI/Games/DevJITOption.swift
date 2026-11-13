#if GAGA_DEV_JIT
import Darwin
import SwiftUI

/// Sideload JIT, DevJIT configuration only (DevJIT.xcconfig, docs/04 section 8.1). A per-game request that the core
/// honours only when a debugger gives it runnable memory (Cores/shared/Jit26.c); otherwise the game runs on the
/// interpreter as in every other build.
enum DevJITOption {
    /// scripts/nojit-gate.sh refuses any store build holding this string. Keep the two in step.
    static let marker = "GAGA_DEV_JIT_OPTION_MARKER"

    /// Cores with a sideload JIT build (Cores/<id>/jit.env, built into build/cores-jit).
    static let cores: Set<String> = ["ppsspp", "dosbox_pure", "pcsx_rearmed", "melonds_ds", "swanstation"]

    static func key(_ gameID: UUID) -> String { marker + "." + gameID.uuidString }

    /// What GameSession hands the core as GAGA_JIT.
    static func requested(gameID: UUID, coreID: String) -> Bool {
        cores.contains(coreID) && UserDefaults.standard.bool(forKey: key(gameID))
    }

    /// A debugger is attached (CS_DEBUGGED), which on iOS 26 is the only way to executable memory. The core still
    /// checks that the debugger maps a region, and falls back to the interpreter when it does not.
    static var debuggerAttached: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        var flags: UInt32 = 0
        return csops(getpid(), 0, &flags, MemoryLayout<UInt32>.size) == 0 && flags & 0x1000_0000 != 0 // CS_OPS_STATUS, CS_DEBUGGED
        #endif
    }
}

@_silgen_name("csops")
private func csops(_ pid: pid_t, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

struct DevJITToggle: View {
    @AppStorage private var isOn: Bool
    private let attached = DevJITOption.debuggerAttached

    init(gameID: UUID) {
        _isOn = AppStorage(wrappedValue: false, DevJITOption.key(gameID))
    }

    var body: some View {
        // Verbatim, so these never enter the string catalog of a normal build.
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "JIT")
                Text(verbatim: attached
                     ? "Debugger attached. Used from the next start of this game if the debugger maps JIT memory."
                     : "No debugger attached, so this game runs on the interpreter. Enable JIT with StikDebug (universal.js) or Xcode, then start the game.")
                    .font(.meta).foregroundStyle(AppTheme.muted)
            }
        }
        .disabled(!attached)
        .padding(.vertical, 6)
        .frame(minHeight: 44)
    }
}
#endif
