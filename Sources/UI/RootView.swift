import SwiftUI

enum AppScreen: String, CaseIterable, Identifiable {
    case library, add, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .library: return "Library"
        case .add: return "Add"
        case .settings: return "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .library: return "books.vertical"
        case .add: return "plus"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @State private var screen: AppScreen = .library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            LeftRail(selection: $screen)
            Rule().ignoresSafeArea(edges: .vertical)
            Group {
                switch screen {
                case .library: LibraryView { screen = .add }
                case .add: AddView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: screen)
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper.ignoresSafeArea())
    }
}

/// Replaces a tab bar: persistent chrome costs width, which landscape has, not height.
private struct LeftRail: View {
    @Binding var selection: AppScreen

    var body: some View {
        VStack(spacing: 4) {
            ForEach(AppScreen.allCases) { item in
                let selected = selection == item
                Button { selection = item } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol).font(.title3.weight(selected ? .semibold : .regular))
                        Text(item.title)
                            .font(.caption2.weight(selected ? .bold : .regular))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                    .foregroundStyle(selected ? AppTheme.accent : AppTheme.muted)
                    .overlay(alignment: .leading) {
                        if selected { Rectangle().fill(AppTheme.accent).frame(width: 3) }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityShowsLargeContentViewer()
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .frame(width: 72)
        // The rail stays one fixed width; the large content viewer covers larger text sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .background(AppTheme.surface.ignoresSafeArea())
    }
}
