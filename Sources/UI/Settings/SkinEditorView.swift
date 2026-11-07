import SwiftUI

extension TouchSkinEngine {
    /// The editor moves and sizes the D-pad with its hidden diagonals, and the second pad, as one piece.
    static func editGroup(of id: String) -> String {
        if ["up", "down", "left", "right", "upleft", "upright", "downleft", "downright"].contains(id) { return "pad" }
        return id.hasPrefix("pad2") ? "pad2" : id
    }

    static func editGroupName(_ group: String) -> String {
        switch group {
        case "pad": return "D-pad"
        case "pad2": return "Right pad"
        default: return label(for: group).spoken
        }
    }

    private static func bounds(_ buttons: [Button], group: String) -> CGRect? {
        buttons.filter { editGroup(of: $0.id) == group }.map(\.frame).reduce(nil) { $0?.union($1) ?? $1 }
    }

    /// Moves a group by a normalized offset, stopped at the canvas edges.
    static func moving(_ buttons: [Button], group: String, by offset: CGSize) -> [Button] {
        guard let box = bounds(buttons, group: group) else { return buttons }
        let dx = min(max(offset.width, -box.minX), 1 - box.maxX)
        let dy = min(max(offset.height, -box.minY), 1 - box.maxY)
        return buttons.map { button in
            guard editGroup(of: button.id) == group else { return button }
            var moved = button
            moved.frame = button.frame.offsetBy(dx: dx, dy: dy)
            return moved
        }
    }

    /// Scales a group about its centre. A size that would leave the canvas is refused, unchanged.
    static func resizing(_ buttons: [Button], group: String, by factor: CGFloat) -> [Button] {
        guard let box = bounds(buttons, group: group) else { return buttons }
        let center = CGPoint(x: box.midX, y: box.midY)
        let scaled = buttons.map { button -> Button in
            guard editGroup(of: button.id) == group else { return button }
            var resized = button
            let f = button.frame
            resized.frame = CGRect(x: center.x + (f.minX - center.x) * factor, y: center.y + (f.minY - center.y) * factor,
                                   width: f.width * factor, height: f.height * factor)
            return resized
        }
        guard let grown = bounds(scaled, group: group),
              grown.minX >= 0, grown.minY >= 0, grown.maxX <= 1, grown.maxY <= 1 else { return buttons }
        return scaled
    }
}

/// Settings > Controls > Assign Skin > Edit: moves, sizes and fades one platform's touch buttons on a landscape
/// canvas shaped like the game view, then saves them as that platform's custom flex skin. Save stays off while
/// `TouchSkinEngine.problems` finds anything, so a saved layout keeps the bands, 44pt targets and no overlaps.
struct SkinEditorView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let platformID: String

    @State private var buttons: [TouchSkinEngine.Button] = []
    @State private var opacity = TouchSkinEngine.defaultOpacity
    @State private var selected: String?
    @State private var dragStart: [TouchSkinEngine.Button]?
    @State private var saveError: String?
    @State private var confirmReset = false

    private var problems: [String] { TouchSkinEngine.problems(in: buttons) }

    /// The layout the platform uses without a custom skin.
    private var builtInButtons: [TouchSkinEngine.Button] {
        let choice = state.platformSkins[platformID] == TouchSkinEngine.customID ? nil : state.platformSkins[platformID]
        let id = TouchSkinEngine.layoutID(game: nil, platform: choice, platformID: platformID)
        return (TouchSkinEngine.Layout.builtIn.first { $0.id == id } ?? .standard).buttons(for: platformID)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                pictureArea(geometry.size)
                ForEach(buttons.filter { $0.shape != .hidden }) { button in
                    control(button, canvas: geometry.size)
                }
            }
        }
        .background(AppTheme.letterbox.ignoresSafeArea())
        .statusBarHidden(true)
        .onAppear(perform: load)
        .confirmationDialog("Reset to the default layout?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset to Default", role: .destructive) {
                state.resetCustomSkin(platformID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The custom layout for \(CoreCatalog.platformName(platformID)) is deleted.")
        }
    }

    private func load() {
        let saved = state.hasCustomSkin(platformID)
            ? (try? Data(contentsOf: state.customSkinURL(platformID))).flatMap { try? TouchSkinEngine.decodeFlex($0, id: platformID) }
            : nil
        buttons = saved?.buttons ?? builtInButtons
        opacity = saved?.opacity ?? TouchSkinEngine.defaultOpacity
    }

    // MARK: Picture area and panel

    /// The picture's place between the bands holds the editor's controls, so they never cover a button.
    private func pictureArea(_ size: CGSize) -> some View {
        let band = TouchSkinEngine.controlBand
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Edit Skin").font(.screenTitle).accessibilityAddTraits(.isHeader)
                Text(CoreCatalog.platformName(platformID)).font(.meta).foregroundStyle(AppTheme.muted)
                Text(selected.map { "Selected: \(TouchSkinEngine.editGroupName($0))" } ?? "Drag a button to move it. Tap one to size it.")
                    .font(.footnote)
                HStack(spacing: 8) {
                    Button("Smaller") { resize(0.9) }.buttonStyle(QuietButtonStyle())
                    Button("Larger") { resize(1.1) }.buttonStyle(QuietButtonStyle())
                }
                .disabled(selected == nil)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Opacity \(Int((opacity * 100).rounded()))%").font(.footnote)
                    Slider(value: $opacity, in: TouchSkinEngine.minimumOpacity...1)
                        .tint(AppTheme.accentFill)
                        .accessibilityLabel("Opacity")
                        .frame(minHeight: 44)
                }
                Text(problems.first ?? saveError ?? "Ready to save.")
                    .font(.footnote).foregroundStyle(problems.isEmpty && saveError == nil ? AppTheme.muted : AppTheme.accent)
                    .accessibilityAddTraits(.updatesFrequently)
                Button("Save", action: save).buttonStyle(PrimaryButtonStyle()).disabled(!problems.isEmpty)
                HStack(spacing: 16) {
                    Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle())
                    Spacer(minLength: 0)
                    Button("Reset to Default") { confirmReset = true }.buttonStyle(QuietButtonStyle())
                }
            }
            .padding(12)
        }
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        .padding(8)
        .frame(width: size.width * (1 - 2 * band), height: size.height)
        .offset(x: size.width * band)
    }

    private func save() {
        do {
            try state.saveCustomSkin(buttons, opacity: opacity, platformID: platformID)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: Buttons

    private func control(_ button: TouchSkinEngine.Button, canvas: CGSize) -> some View {
        let group = TouchSkinEngine.editGroup(of: button.id)
        let isSelected = selected == group
        let name = TouchSkinEngine.label(for: button.id)
        return glyph(button, label: name.glyph, selected: isSelected)
            .opacity(opacity)
            .frame(width: button.frame.width * canvas.width, height: button.frame.height * canvas.height)
            .contentShape(Rectangle())
            .position(x: button.frame.midX * canvas.width, y: button.frame.midY * canvas.height)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = buttons
                        selected = group
                        saveError = nil
                    }
                    guard let start = dragStart else { return }
                    buttons = TouchSkinEngine.moving(start, group: group, by: CGSize(width: value.translation.width / canvas.width,
                                                                                     height: value.translation.height / canvas.height))
                }
                .onEnded { _ in dragStart = nil })
            .accessibilityElement()
            .accessibilityLabel(name.spoken)
            .accessibilityValue(isSelected ? "Selected" : "")
            .accessibilityHint("Drag to move. Actions move and size \(TouchSkinEngine.editGroupName(group)).")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { selected = group }
            .accessibilityAction(named: "Move Left") { nudge(group, -0.02, 0) }
            .accessibilityAction(named: "Move Right") { nudge(group, 0.02, 0) }
            .accessibilityAction(named: "Move Up") { nudge(group, 0, -0.04) }
            .accessibilityAction(named: "Move Down") { nudge(group, 0, 0.04) }
            .accessibilityAction(named: "Larger") { selected = group; resize(1.1) }
            .accessibilityAction(named: "Smaller") { selected = group; resize(0.9) }
    }

    @ViewBuilder private func glyph(_ button: TouchSkinEngine.Button, label: String?, selected: Bool) -> some View {
        let content = selected ? AppTheme.onAccent : AppTheme.onLetterbox
        let fill = selected ? AppTheme.accentFill : Color.clear
        if button.shape == .circle {
            Circle().fill(fill)
                .overlay(Circle().stroke(AppTheme.onLetterbox, lineWidth: selected ? 2 : 1))
                .overlay(Text(label ?? "").font(.system(.headline, design: .serif)).foregroundStyle(content))
        } else {
            RoundedRectangle(cornerRadius: AppTheme.corner).fill(fill)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.onLetterbox, lineWidth: selected ? 2 : 1))
                .overlay(Group {
                    if let arrow = Self.arrow(button.shape) {
                        Image(systemName: arrow)
                    } else {
                        Text(label ?? "").font(.meta).lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 4)
                    }
                }.foregroundStyle(content))
        }
    }

    private static func arrow(_ shape: TouchSkinEngine.Button.Shape) -> String? {
        switch shape {
        case .dpup: return "arrowtriangle.up.fill"
        case .dpdown: return "arrowtriangle.down.fill"
        case .dpleft: return "arrowtriangle.left.fill"
        case .dpright: return "arrowtriangle.right.fill"
        default: return nil
        }
    }

    private func resize(_ factor: CGFloat) {
        guard let selected else { return }
        buttons = TouchSkinEngine.resizing(buttons, group: selected, by: factor)
        saveError = nil
    }

    private func nudge(_ group: String, _ dx: CGFloat, _ dy: CGFloat) {
        selected = group
        buttons = TouchSkinEngine.moving(buttons, group: group, by: CGSize(width: dx, height: dy))
        saveError = nil
    }
}
