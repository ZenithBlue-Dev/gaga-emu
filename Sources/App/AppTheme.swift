import Observation
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

/// The chosen accent colour. Observable, so every view that reads an `AppTheme` accent redraws when it changes.
@Observable final class ThemeStore {
    static let shared = ThemeStore()
    var accentHex: Int?
}

/// Any picked colour made safe: text and glyph tones reach AA on paper in each appearance, the fill under `onAccent`.
struct ThemeAccent: Equatable {
    let light, dark, fill: Int

    init(_ hex: Int) {
        light = Self.adjusted(hex, toward: 0x000000) { Self.contrast($0, Palette.paper.light) }
        dark = Self.adjusted(hex, toward: 0xFFFFFF) { Self.contrast($0, Palette.surface.dark) }
        fill = Self.adjusted(hex, toward: 0xFFFFFF) { Self.contrast($0, Palette.onAccent) }
    }

    private static func adjusted(_ hex: Int, toward target: Int, contrast: (Int) -> Double) -> Int {
        for step in 0...20 {
            let mixed = mix(hex, target, Double(step) / 20)
            if contrast(mixed) >= 4.5 { return mixed }
        }
        return target
    }

    private static func mix(_ a: Int, _ b: Int, _ k: Double) -> Int {
        [16, 8, 0].reduce(0) { sum, shift in
            let from = Double(a >> shift & 0xFF), to = Double(b >> shift & 0xFF)
            return sum | Int((from + (to - from) * k).rounded()) << shift
        }
    }

    static func contrast(_ a: Int, _ b: Int) -> Double {
        func luminance(_ hex: Int) -> Double {
            let parts = [16, 8, 0].map { shift -> Double in
                let c = Double(hex >> shift & 0xFF) / 255
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * parts[0] + 0.7152 * parts[1] + 0.0722 * parts[2]
        }
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
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
            // One line when it fits; otherwise Close goes above a title that wraps, so nothing runs off the edge.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(title).font(.screenTitle).accessibilityAddTraits(.isHeader).layoutPriority(1)
                    if let subtitle { Text(subtitle).font(.meta).foregroundStyle(AppTheme.muted).lineLimit(2) }
                    Spacer(minLength: 0)
                    close
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack { Spacer(minLength: 0); close }
                    Text(title).font(.screenTitle).accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle).font(.meta).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, 6)
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

    private var close: some View { Button("Close") { dismiss() }.buttonStyle(QuietButtonStyle()) }
}

enum AppTheme {
    static let paper = Color(Palette.paper)
    static let surface = Color(Palette.surface)
    static let ink = Color(Palette.ink)
    static let muted = Color(Palette.muted)
    static let rule = Color(Palette.rule)
    private static var chosen: ThemeAccent? { ThemeStore.shared.accentHex.map(ThemeAccent.init) }
    static var accent: Color { chosen.map { Color((light: $0.light, dark: $0.dark)) } ?? Color(Palette.accent) }
    static var accentFill: Color { Color(hex: chosen?.fill ?? Palette.accentFill) }
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
