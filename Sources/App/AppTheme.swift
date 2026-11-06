import SwiftUI

/// Dark OLED palette from the Manic reference screenshots.
enum AppTheme {
    static let background = Color(red: 0x0B / 255, green: 0x0C / 255, blue: 0x10 / 255)
    static let card = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
    static let cardRaised = Color(red: 0x2C / 255, green: 0x2C / 255, blue: 0x2E / 255)
    static let stroke = Color.white.opacity(0.06)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.62)
    static let textTertiary = Color(white: 0.42)
    static let accent = Color(red: 1, green: 0.30, blue: 0.42)
    static let accentBlue = Color(red: 0.45, green: 0.36, blue: 1)
    static let accentGreen = Color(red: 0.20, green: 0.78, blue: 0.45)
    static let warning = Color(red: 1, green: 0.72, blue: 0.20)
    static let radius: CGFloat = 22

    static let brandGradient = LinearGradient(
        colors: [Color(red: 1, green: 0.30, blue: 0.42), Color(red: 0.55, green: 0.36, blue: 1)],
        startPoint: .leading, endPoint: .trailing)

    static let membershipGradient = LinearGradient(
        colors: [Color(red: 1, green: 0.45, blue: 0.55), Color(red: 0.72, green: 0.42, blue: 0.95)],
        startPoint: .leading, endPoint: .trailing)
}

struct GlassCard: ViewModifier {
    var radius: CGFloat = AppTheme.radius
    func body(content: Content) -> some View {
        content
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(AppTheme.stroke, lineWidth: 1))
    }
}

extension View {
    func glassCard(radius: CGFloat = AppTheme.radius) -> some View { modifier(GlassCard(radius: radius)) }
}

/// Floating bottom bar: rocket, folder, gear. The active tab is a gradient pill.
struct GlassTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button { selection = tab } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: .semibold))
                        if selection == tab {
                            Text(tab.title).font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: selection == tab ? .infinity : 64)
                    .frame(height: 52)
                    .background {
                        if selection == tab {
                            Capsule().fill(AppTheme.brandGradient)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.stroke, lineWidth: 1))
        .padding(.horizontal, 28)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case games, importHub, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .games: return "Games"
        case .importHub: return "Import"
        case .settings: return "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .games: return "paperplane.fill"
        case .importHub: return "square.and.arrow.down"
        case .settings: return "gearshape.fill"
        }
    }
}

struct RoundIconButton: View {
    let systemName: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName)
    }
}
