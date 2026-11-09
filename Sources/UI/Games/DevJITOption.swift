#if GAGA_DEV_JIT
import SwiftUI

/// Development builds only (DevJIT.xcconfig). Stores a per-game preference and nothing reads it: no JIT exists yet.
enum DevJITOption {
    /// scripts/nojit-gate.sh refuses any store build holding this string. Keep the two in step.
    static let marker = "GAGA_DEV_JIT_OPTION_MARKER"

    /// Cores in Cores/ whose upstream has an arm64 recompiler (docs/04 section 8.1).
    static let cores: Set<String> = [
        "azahar", "beetle_psx", "dosbox_pure", "flycast", "melonds_ds",
        "mupen64plus_next", "pcsx_rearmed", "picodrive", "ppsspp", "swanstation",
    ]
}

struct DevJITToggle: View {
    @AppStorage private var isOn: Bool

    init(gameID: UUID) {
        _isOn = AppStorage(wrappedValue: false, DevJITOption.marker + "." + gameID.uuidString)
    }

    var body: some View {
        // Verbatim, so these never enter the string catalog of a normal build.
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "JIT mode (not functional)")
                Text(verbatim: "Saved for this game only. No JIT runs yet.")
                    .font(.meta).foregroundStyle(AppTheme.muted)
            }
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
    }
}
#endif
