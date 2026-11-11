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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64, maximum: 64), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
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
                        .frame(width: 64, alignment: .top)
                        .frame(minHeight: 44)
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

/// Style > Icon and Colours: appearance, accent colour and app icon, each chosen from a picture.
struct AppearancePane: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dynamicTypeSize) private var typeSize

    /// `nil` hex is the standard vermilion.
    private static let swatches: [(name: String, hex: Int?)] = [
        ("Vermilion", nil), ("Indigo", 0x4A5BD4), ("Moss", 0x5E8C3A), ("Teal", 0x1E9A98), ("Plum", 0x9A4BA6)
    ]
    private static let modes: [(AppearanceMode, String)] = [(.system, "Automatic"), (.light, "Light"), (.dark, "Dark")]

    private var customColour: Binding<Color> {
        Binding(get: {
            Color(rgb: state.accentHex ?? Palette.accentFill)
        }, set: { colour in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(colour).getRed(&r, green: &g, blue: &b, alpha: &a)
            let channel = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
            state.accentHex = channel(r) << 16 | channel(g) << 8 | channel(b)
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Appearance")
            HStack(alignment: .top, spacing: 12) {
                ForEach(Self.modes, id: \.1) { mode, name in
                    let selected = state.appearanceChoice == mode
                    Button { state.appearanceChoice = mode } label: {
                        VStack(spacing: 4) {
                            OptionTile { AppearancePicture(mode: mode) }
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.corner + 4).stroke(selected ? AppTheme.ink : Color.clear, lineWidth: 2))
                            Text(LocalizedStringKey(name)).font(.caption.weight(selected ? .bold : .regular))
                                .lineLimit(2, reservesSpace: true).multilineTextAlignment(.center)
                        }
                        // One width for all three, so the pictures line up.
                        .frame(width: typeSize.isAccessibilitySize ? nil : 80, alignment: .top)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(LocalizedStringKey(name))
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .padding(.vertical, 6)
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
    }

    private func swatch(name: String, hex: Int?) -> some View {
        let selected = state.accentHex == hex
        return Button { state.accentHex = hex } label: {
            // A mini cover in the colour: the spine and a title bar, as the Library draws them.
            RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.surface)
                .overlay(alignment: .leading) { Rectangle().fill(Color(rgb: hex ?? Palette.accentFill)).frame(width: 8) }
                .overlay(alignment: .bottom) { Capsule().fill(Color(rgb: hex ?? Palette.accentFill)).frame(width: 16, height: 3).padding(.bottom, 6) }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 30, height: 38)
                .overlay {
                    // A mark as well as a ring, so the choice does not rest on colour alone.
                    if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(AppTheme.ink) }
                }
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(selected ? AppTheme.ink : AppTheme.rule, lineWidth: selected ? 2 : 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Style > Library Layout: how the Library draws its shelves, with a mini shelf that follows every change.
struct LibraryLayoutPane: View {
    @EnvironmentObject private var state: AppState
    @ScaledMetric(relativeTo: .body) private var previewHeight: CGFloat = 110

    var body: some View {
        ShelfPicture(display: state.libraryDisplay)
            .frame(maxWidth: 360)
            .frame(height: min(previewHeight, 200))
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.corner))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
            .accessibilityElement()
            .accessibilityLabel(ShelfPicture.description(state.libraryDisplay))
            .accessibilityAddTraits(.isImage)
            .padding(.bottom, 8)
        sectionTitle("Shelves")
        rowPicker("Games per Row", selection: $state.libraryDisplay.perRow) {
            Text("Auto").tag(0)
            ForEach(2...5, id: \.self) { Text("\($0)").tag($0) }
        }
        Rule()
        menuRow("Sort By", selection: $state.libraryDisplay.sort, cases: LibraryDisplay.Sort.allCases, label: \.label)
        Rule()
        ToggleRow(title: "Reverse Order", note: "Sorts Z to A, or newest and longest first.", isOn: $state.libraryDisplay.descending,
                  tile: .symbol("arrow.up.arrow.down"))
        Rule()
        ToggleRow(title: "Hide Scroll Indicators", note: "No bar at the edge of the shelves while they scroll.", isOn: $state.libraryDisplay.hideIndicators,
                  tile: .symbol("scroll"))
        Rule()
        menuRow("Shelf Title", selection: $state.libraryDisplay.groupStyle, cases: LibraryDisplay.GroupStyle.allCases, label: \.label)
        Rule()
        ToggleRow(title: "Hide Shelf Titles", note: "Shelves follow each other without a heading.", isOn: $state.libraryDisplay.hideGroup,
                  tile: .symbol("textformat"))
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
        ToggleRow(title: "Square Covers", note: "Every cover is cut to a square.", isOn: $state.libraryDisplay.square, tile: .symbol("square"))
        Rule()
        ToggleRow(title: "Hide Game Titles", note: "Only the cover shows on a shelf.", isOn: $state.libraryDisplay.hideTitle, tile: .symbol("character.textbox"))
        Rule()
        ToggleRow(title: "Hide Details", note: "No favorite star, system or play time under a cover.", isOn: $state.libraryDisplay.hideDetails,
                  tile: .symbol("info.square"))
        Rule()
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
