import SwiftUI

/// First-run tips: one line each, shown where it applies until Got It, and shown again after Settings > About >
/// Reset Tips. Dismissed tips are kept in UserDefaults, not state.json: they are a view preference.
enum Tip: String, CaseIterable {
    case holdGame, dropFiles, editSkin

    static let storageKey = "GagaDismissedTips"

    var text: String {
        switch self {
        case .holdGame: return "Touch and hold a game to change its core, filter, skin or saves."
        case .dropFiles: return "You can also drop files on the Library or on a running game."
        case .editSkin: return "Choose Edit beside a system to move, resize and fade its touch buttons."
        }
    }

    static func reset() { UserDefaults.standard.removeObject(forKey: storageKey) }
}

struct TipLine: View {
    let tip: Tip
    /// Comma-separated `Tip` raw values.
    @AppStorage(Tip.storageKey) private var dismissed = ""
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if !dismissed.split(separator: ",").contains(Substring(tip.rawValue)) {
            // At accessibility sizes Got It goes under the text, which keeps its full height.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "lightbulb").foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                    Text(tip.text).font(.footnote).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button("Got It") { dismissed = (dismissed.isEmpty ? "" : dismissed + ",") + tip.rawValue }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityHint("Hides this tip")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.corner))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Tip")
        }
    }
}
