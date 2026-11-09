import SwiftUI

/// GagaEmu's own alternate icons, from `design/icons`. iOS shows its own notice after a change.
struct AppIconPicker: View {
    /// `icon` is the asset catalog's alternate name; nil is the primary icon.
    static let choices: [(name: String, icon: String?, preview: String)] = [
        ("Steps", nil, "IconPreviewSteps"), ("Two Beats", "AppIconTwoBeats", "IconPreviewTwoBeats"), ("Folio", "AppIconFolio", "IconPreviewFolio"),
        ("Shelf", "AppIconShelf", "IconPreviewShelf"), ("Well", "AppIconWell", "IconPreviewWell"), ("Phosphor", "AppIconPhosphor", "IconPreviewPhosphor")
    ]

    @State private var current = UIApplication.shared.alternateIconName
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("App Icon")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
                ForEach(Self.choices, id: \.name) { choice in
                    let selected = current == choice.icon
                    Button { set(choice.icon) } label: {
                        VStack(spacing: 2) {
                            Image(choice.preview).resizable().frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? AppTheme.ink : AppTheme.rule, lineWidth: selected ? 2 : 1))
                            Text(LocalizedStringKey(choice.name))
                                .font(.caption2.weight(selected ? .bold : .regular))
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(minWidth: 64, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("App icon, \(choice.name)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            if let failure { Text(failure).font(.footnote).foregroundStyle(AppTheme.accent) }
        }
        .padding(.vertical, 6)
    }

    private func set(_ icon: String?) {
        guard icon != current else { return }
        failure = nil
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(icon)
                current = icon
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

/// Settings > Display: the app's appearance and accent, and how the Library draws its shelves.
struct DisplayPane: View {
    @EnvironmentObject private var state: AppState

    /// `nil` hex is the standard vermilion.
    private static let swatches: [(name: String, hex: Int?)] = [
        ("Vermilion", nil), ("Indigo", 0x4A5BD4), ("Moss", 0x5E8C3A), ("Teal", 0x1E9A98), ("Plum", 0x9A4BA6)
    ]

    private var customColour: Binding<Color> {
        Binding(get: {
            Color(UIColor(red: CGFloat((state.accentHex ?? Palette.accentFill) >> 16 & 0xFF) / 255,
                          green: CGFloat((state.accentHex ?? Palette.accentFill) >> 8 & 0xFF) / 255,
                          blue: CGFloat((state.accentHex ?? Palette.accentFill) & 0xFF) / 255, alpha: 1))
        }, set: { colour in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(colour).getRed(&r, green: &g, blue: &b, alpha: &a)
            let channel = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
            state.accentHex = channel(r) << 16 | channel(g) << 8 | channel(b)
        })
    }

    var body: some View {
        rowPicker("Appearance", selection: $state.appearanceChoice) {
            Text("Automatic").tag(AppearanceMode.system)
            Text("Light").tag(AppearanceMode.light)
            Text("Dark").tag(AppearanceMode.dark)
        }
        Rule()
        VStack(alignment: .leading, spacing: 4) {
            Text("Accent Colour")
            HStack(spacing: 6) {
                ForEach(Self.swatches, id: \.name) { swatch(name: $0.name, hex: $0.hex) }
                Spacer(minLength: 0)
                ColorPicker("Custom accent colour", selection: customColour, supportsOpacity: false)
                    .labelsHidden()
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.vertical, 6)
        Rule()
        AppIconPicker()
        Rule()
        sectionTitle("Shelves")
        rowPicker("Games per Row", selection: $state.libraryDisplay.perRow) {
            Text("Auto").tag(0)
            ForEach(2...5, id: \.self) { Text("\($0)").tag($0) }
        }
        Rule()
        menuRow("Sort By", selection: $state.libraryDisplay.sort, cases: LibraryDisplay.Sort.allCases, label: \.label)
        Rule()
        ToggleRow(title: "Reverse Order", note: "Sorts Z to A, or newest and longest first.", isOn: $state.libraryDisplay.descending)
        Rule()
        ToggleRow(title: "Hide Scroll Indicators", note: "No bar at the edge of the shelves while they scroll.", isOn: $state.libraryDisplay.hideIndicators)
        Rule()
        menuRow("Shelf Title", selection: $state.libraryDisplay.groupStyle, cases: LibraryDisplay.GroupStyle.allCases, label: \.label)
        Rule()
        ToggleRow(title: "Hide Shelf Titles", note: "Shelves follow each other without a heading.", isOn: $state.libraryDisplay.hideGroup)
        Rule()
        sectionTitle("Covers")
        rowPicker("Cover Style", selection: $state.libraryDisplay.coverStyle) {
            ForEach(LibraryDisplay.CoverStyle.allCases) { Text($0.label).tag($0) }
        }
        Rule()
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Corner Radius")
                Spacer(minLength: 12)
                Text("\(Int(state.libraryDisplay.corner)) pt").font(.meta).foregroundStyle(AppTheme.muted)
            }
            Slider(value: $state.libraryDisplay.corner, in: 0...16, step: 2) { Text("Corner Radius") }
                .tint(AppTheme.accentFill)
                .accessibilityValue("\(Int(state.libraryDisplay.corner)) points")
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        Rule()
        ToggleRow(title: "Square Covers", note: "Every cover is cut to a square.", isOn: $state.libraryDisplay.square)
        Rule()
        ToggleRow(title: "Hide Game Titles", note: "Only the cover shows on a shelf.", isOn: $state.libraryDisplay.hideTitle)
        Rule()
        ToggleRow(title: "Hide Details", note: "No favorite star, system or play time under a cover.", isOn: $state.libraryDisplay.hideDetails)
        Rule()
    }

    private func swatch(name: String, hex: Int?) -> some View {
        let selected = state.accentHex == hex
        return Button { state.accentHex = hex } label: {
            Circle()
                .fill(Color(UIColor(red: CGFloat((hex ?? Palette.accentFill) >> 16 & 0xFF) / 255,
                                    green: CGFloat((hex ?? Palette.accentFill) >> 8 & 0xFF) / 255,
                                    blue: CGFloat((hex ?? Palette.accentFill) & 0xFF) / 255, alpha: 1)))
                .frame(width: 28, height: 28)
                .overlay {
                    // A mark as well as a ring, so the choice does not rest on colour alone.
                    if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(AppTheme.onAccent) }
                }
                .overlay(Circle().stroke(selected ? AppTheme.ink : AppTheme.rule, lineWidth: selected ? 2 : 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader).padding(.top, 16).padding(.bottom, 4)
    }

    private func rowPicker<Value: Hashable, Options: View>(_ title: String, selection: Binding<Value>, @ViewBuilder options: () -> Options) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Picker(title, selection: selection, content: options).pickerStyle(.segmented).labelsHidden().frame(minHeight: 44)
        }
        .padding(.vertical, 6)
    }

    private func menuRow<Value: Hashable & Identifiable>(_ title: String, selection: Binding<Value>, cases: [Value], label: KeyPath<Value, String>) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Picker(title, selection: selection) {
                ForEach(cases) { Text($0[keyPath: label]).tag($0) }
            }
            .labelsHidden()
        }
        .frame(minHeight: 44)
    }
}
