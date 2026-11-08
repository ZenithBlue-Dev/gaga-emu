import SwiftUI
import UIKit

/// "Paper and ink" colours as (light, dark) hex pairs, spec in docs/06 section 3.
enum Palette {
    static let paper = (light: 0xF4EFE6, dark: 0x16140F)
    static let surface = (light: 0xFBF8F2, dark: 0x211E18)
    static let ink = (light: 0x1C1A17, dark: 0xEDE6D8)
    static let muted = (light: 0x6B655B, dark: 0xA79F90)
    static let rule = (light: 0xD9D1C2, dark: 0x3A352C)
    /// Vermilion darkened on paper and lightened on dark, so accent text and glyphs reach AA.
    static let accent = (light: 0xBF3D18, dark: 0xF0683F)
    /// True vermilion, used only as a fill under `onAccent`.
    static let accentFill = 0xE4572E
    static let onAccent = 0x1C1A17
}

private extension Color {
    init(_ pair: (light: Int, dark: Int)) {
        self.init(UIColor { UIColor(hex: $0.userInterfaceStyle == .dark ? pair.dark : pair.light) })
    }

    init(hex: Int) { self.init(UIColor(hex: hex)) }
}

private extension UIColor {
    convenience init(hex: Int) {
        self.init(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Font {
    static let screenTitle = Font.system(.title2, design: .serif).weight(.semibold)
    static let gameTitle = Font.system(.title3, design: .serif).weight(.semibold)
    /// Platform code, play time, file size.
    static let meta = Font.system(.caption, design: .monospaced)
}

/// Hairline in place of shadows and cards. Follows a plain stack's axis. Inside `AnyLayout` a Divider cannot see the
/// axis and lies flat, taking a share of the row's width, so a vertical rule there passes `vertical: true`.
struct Rule: View {
    var vertical = false
    @Environment(\.displayScale) private var scale

    var body: some View {
        if vertical {
            AppTheme.rule.frame(width: 1 / scale)
        } else {
            Divider().overlay(AppTheme.rule)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? AppTheme.onAccent : AppTheme.muted)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isEnabled ? AppTheme.accentFill : AppTheme.rule,
                        in: RoundedRectangle(cornerRadius: AppTheme.corner))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Text button in the accent colour, with a full-size target.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.accent)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Header plus content for every sheet. `scrolls: false` is for content that scrolls itself.
struct PaperSheet<Content: View>: View {
    let title: String
    var subtitle: String?
    var scrolls = true
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title).font(.screenTitle).accessibilityAddTraits(.isHeader).layoutPriority(1)
                if let subtitle { Text(subtitle).font(.meta).foregroundStyle(AppTheme.muted).lineLimit(2) }
                Spacer(minLength: 0)
                Button("Close") { dismiss() }.buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, 20)
            Rule()
            if scrolls {
                ScrollView {
                    content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                content
            }
        }
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper.ignoresSafeArea())
        .presentationCornerRadius(AppTheme.corner)
    }
}

enum AppTheme {
    static let paper = Color(Palette.paper)
    static let surface = Color(Palette.surface)
    static let ink = Color(Palette.ink)
    static let muted = Color(Palette.muted)
    static let rule = Color(Palette.rule)
    static let accent = Color(Palette.accent)
    static let accentFill = Color(hex: Palette.accentFill)
    static let onAccent = Color(hex: Palette.onAccent)
    /// Around the game picture, in both appearances: a picture needs a dark surround.
    static let letterbox = Color(hex: Palette.ink.light)
    static let onLetterbox = Color(hex: Palette.ink.dark)
    static let corner: CGFloat = 6

    /// Left spine on covers. One muted hue per catalog platform; the code text is the non-colour cue.
    static func spine(_ platformID: String) -> Color {
        guard let index = CoreCatalog.platforms.firstIndex(where: { $0.id == platformID }) else { return muted }
        return Color(hue: Double(index) / Double(CoreCatalog.platforms.count), saturation: 0.6, brightness: 0.7)
    }
}
