import SwiftUI

/// Settings > Help > JIT: whether this build can use JIT and the cores with a sideload JIT build.
/// The live check is compiled only in the DevJIT configuration (Sources/UI/Games/DevJITOption.swift); every other
/// build shows the static text and holds no JIT code.
enum JITStatus {
    static var status: String {
        #if GAGA_DEV_JIT
        DevJITOption.debuggerAttached ? String(localized: "Available, debugger attached")
            : String(localized: "Not enabled. Open GagaEmu with StikDebug.")
        #else
        String(localized: "Not available in this version")
        #endif
    }
}

struct JITStatusView: View {
    var body: some View {
        PaperSheet(title: "JIT") {
            VStack(alignment: .leading, spacing: 0) {
                Text("JIT (just-in-time compilation) makes some systems run much faster. Apple does not allow it in App Store apps, so this version runs every core as an interpreter. The sideload build can use JIT on the cores below when a debugger such as StikDebug enables it.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.vertical, 8)
                Rule()
                ValueRow(title: "Status", value: JITStatus.status)
                    .accessibilityIdentifier("jit.status")
                Rule()
                Text("Cores with JIT in the sideload build").font(.meta).foregroundStyle(AppTheme.muted)
                    .padding(.top, 16).padding(.bottom, 4).accessibilityAddTraits(.isHeader)
                ForEach(CoreCatalog.sideloadJITCoreRows, id: \.name) { row in
                    ValueRow(title: row.name, value: row.systems)
                        .accessibilityIdentifier("jit.core")
                    Rule()
                }
                Text("A sideload build with JIT is available.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 8)
            }
        }
    }
}
