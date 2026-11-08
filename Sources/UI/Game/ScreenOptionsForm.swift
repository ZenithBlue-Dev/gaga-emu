import SwiftUI

/// A choice the screen options list in a menu.
protocol ScreenChoice: CaseIterable, Identifiable, Hashable where AllCases == [Self] {
    var title: String { get }
}

extension ScalingMode: ScreenChoice {}
extension PictureArea: ScreenChoice {}
extension DualPreset: ScreenChoice {}
extension SmallPlacement: ScreenChoice {}
extension ScreenRotation: ScreenChoice {}

/// Scaling, picture area and, for a two-screen system, the layout. The pause menu edits the running game's
/// choice live; Settings > Graphics > Screen edits a system's.
struct ScreenOptionsForm: View {
    @Binding var settings: ScreenSettings
    let platformID: String
    let dual: Bool
    /// The pause menu's "This Game Only". Nil in Settings, which always sets the system's choice.
    var gameOnly: Binding<Bool>?
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let gameOnly {
                toggle("This Game Only", note: "Off: every \(CoreCatalog.platformName(platformID)) game uses these.", isOn: gameOnly)
                Rule()
            }
            choice("Scaling", $settings.scaling)
            note(scalingNote)
            Rule()
            choice("Picture Area", $settings.area)
            note(settings.area == .fullScreen
                 ? "The picture uses the whole screen, under the touch controls."
                 : "The picture stays between the touch controls. With a controller and Auto Full Screen on, it uses the whole screen.")
            Rule()
            if dual { dualOptions }
        }
        .fullScreenCover(isPresented: $editing) { ScreenLayoutEditorView(settings: $settings, platformID: platformID) }
    }

    private var scalingNote: String {
        switch settings.scaling {
        case .fit: return "As large as fits, in its own shape."
        case .stretch: return "Fills the area. The picture changes shape."
        case .integer: return "The largest whole-number size, so every pixel is the same size."
        case .zoom: return "Fills the area in its own shape. The edges are cut off."
        }
    }

    @ViewBuilder private var dualOptions: some View {
        choice("Layout", $settings.preset)
        if settings.preset == .custom {
            note(settings.customTop == nil ? "Edit the custom layout to place the screens. Until then they are stacked." : "Your own layout. It uses the whole screen.")
        }
        Button("Edit Custom Layout") { editing = true }
            .buttonStyle(QuietButtonStyle())
            .frame(minHeight: 44)
        Rule()
        if settings.preset.usesSmallScreen {
            choice("Small Screen", $settings.smallPlacement)
            Rule()
            slider("Small Screen Size", value: $settings.smallScale, in: ScreenSettings.smallScaleRange, step: 0.05,
                   text: "\(Int((settings.smallScale * 100).rounded()))%")
            Rule()
        }
        toggle("Swap Screens", note: settings.preset == .single
               ? "Shows the bottom screen instead. Options and R1 on a controller, or the swap button, switch while you play."
               : "Exchanges the two screens. Options and R1 on a controller, or the swap button, do this while you play.",
               isOn: $settings.swapped)
        Rule()
        toggle("Show Top Screen", note: "", isOn: show(\.showTop, other: \.showBottom))
            .disabled(settings.showTop && !settings.showBottom)
        Rule()
        toggle("Show Bottom Screen", note: "Hidden, the touch screen takes no touch.", isOn: show(\.showBottom, other: \.showTop))
            .disabled(settings.showBottom && !settings.showTop)
        Rule()
        if settings.preset != .single && settings.preset != .custom {
            slider("Gap", value: $settings.gap, in: ScreenSettings.gapRange, step: 4,
                   text: settings.gap == 0 ? "None" : "\(Int(settings.gap)) pixels")
            Rule()
        }
        choice("Rotation", $settings.rotation)
        note("Turns both screens, for games you hold like a book.")
        Rule()
    }

    /// One screen can be hidden, never both.
    private func show(_ key: WritableKeyPath<ScreenSettings, Bool>, other: KeyPath<ScreenSettings, Bool>) -> Binding<Bool> {
        Binding(get: { settings[keyPath: key] },
                set: { if $0 || settings[keyPath: other] { settings[keyPath: key] = $0 } })
    }

    // MARK: Rows

    private func choice<T: ScreenChoice>(_ title: String, _ selection: Binding<T>) -> some View {
        let picker = Picker(title, selection: selection) {
            ForEach(T.allCases) { Text($0.title).tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(AppTheme.accent)
        // Large text puts the menu under its title instead of squeezing both onto one line.
        return ViewThatFits(in: .horizontal) {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                picker
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                picker
            }
        }
        .frame(minHeight: 44)
    }

    private func toggle(_ title: String, note text: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !text.isEmpty { Text(text).font(.footnote).foregroundStyle(AppTheme.muted) }
            }
        }
        .tint(AppTheme.accentFill)
        .padding(.vertical, 6)
        .frame(minHeight: 44)
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                Text(text).font(.meta).foregroundStyle(AppTheme.muted)
            }
            Slider(value: value, in: range, step: step) { Text(title) }
                .tint(AppTheme.accentFill)
                .accessibilityValue(text)
                .frame(minHeight: 44)
        }
        .padding(.vertical, 4)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(AppTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 6)
    }
}

/// Settings > Graphics > Screen: each system's choice. A game's own choice is made from its pause menu.
struct ScreenSettingsView: View {
    @ObservedObject var store: ScreenLayoutStore
    @State private var platformID = CoreCatalog.platforms.first { ScreenLayout.isDual($0.id) }?.id ?? CoreCatalog.platforms.first?.id ?? ""

    var body: some View {
        PaperSheet(title: "Screen") {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("System")
                    Spacer(minLength: 12)
                    Picker("System", selection: $platformID) {
                        ForEach(CoreCatalog.platforms) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    .tint(AppTheme.accent)
                }
                .frame(minHeight: 44)
                Rule()
                ScreenOptionsForm(settings: binding, platformID: platformID, dual: ScreenLayout.isDual(platformID))
                    .id(platformID)
                Text("To choose for one game, open the pause menu in that game and turn on This Game Only.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 8)
            }
        }
    }

    private var binding: Binding<ScreenSettings> {
        Binding(get: { store.settings(platformID: platformID, gameID: nil) },
                set: { store.save($0, platformID: platformID, gameID: nil) })
    }
}
