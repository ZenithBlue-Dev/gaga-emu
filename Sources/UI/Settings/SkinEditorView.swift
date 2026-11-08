import SwiftUI
import UniformTypeIdentifiers

extension TouchSkinEngine {
    /// The editor moves and sizes the D-pad with its hidden diagonals, and the second pad, as one piece.
    static func editGroup(of id: String) -> String {
        if ["up", "down", "left", "right", "upleft", "upright", "downleft", "downright"].contains(id) { return "pad" }
        return id.hasPrefix("pad2") ? "pad2" : id
    }

    static func editGroupName(_ group: String, in buttons: [Button] = [], macros: [Macro] = []) -> String {
        switch group {
        case "pad": return "D-pad"
        case "pad2": return "Right pad"
        default: return buttons.first { $0.id == group }.map { label(for: $0, macros: macros).spoken } ?? label(for: group).spoken
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

    /// The D-pad with or without its corner areas, which press two directions at once. Rebuilt from the four arrows.
    static func withDiagonals(_ buttons: [Button], _ on: Bool) -> [Button] {
        let corners: Set<String> = ["upleft", "upright", "downleft", "downright"]
        let rest = buttons.filter { !corners.contains($0.id) }
        guard on, let up = buttons.first(where: { $0.id == "up" }), let left = buttons.first(where: { $0.id == "left" }) else { return rest }
        return rest + Layout.diagonals(topY: up.frame.minY, padX: left.frame.minX, width: up.frame.width, height: left.frame.height)
    }

    /// A new element for the palette, in the middle of the control area, with an id no other element has.
    static func newElement(_ action: ControlAction?, stick: String? = nil, in buttons: [Button], portrait: Bool) -> Button {
        let base: String
        switch action {
        case .buttons(let mask): base = "btn\(mask)"
        case .app(let function): base = function.rawValue
        case .turbo(let mask, let toggle): base = "turbo\(mask)\(toggle ? "t" : "")"
        case .macro(let id): base = "macro-\(id.uuidString.prefix(8))"
        case nil: base = stick ?? "element"
        }
        let ids = Set(buttons.map(\.id))
        let id = ids.contains(base) ? (2...).lazy.map { "\(base)-\($0)" }.first { !ids.contains($0) }! : base
        let isStick = stick != nil
        let size = portrait ? CGSize(width: isStick ? 0.22 : 0.132, height: isStick ? 0.11 : 0.064)
            : CGSize(width: isStick ? 0.11 : 0.065, height: isStick ? 0.2236 : 0.13)
        let center = portrait ? CGPoint(x: 0.5, y: 0.75) : CGPoint(x: 0.1, y: 0.5)
        var button = Button(id: id, frame: CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                                                  width: size.width, height: size.height),
                            mask: 0, asset: nil, shape: isStick ? .stick : .circle)
        if case .buttons(let mask) = action { button.mask = mask } else { button.action = action }
        return button
    }
}

/// A flex skin file, for Export.
struct SkinDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// Settings > Controls > Touch Layout > Edit: moves, sizes and fades one platform's touch controls, or one game's,
/// in each orientation, on a canvas shaped like the game view, then saves them as a custom flex skin. Save stays
/// off while `TouchSkinEngine.problems` finds anything in either orientation, so a saved layout keeps the picture
/// clear (unless overlay is on), 44pt targets and no overlaps.
struct SkinEditorView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let platformID: String
    /// Edits this game's own layout in place of the platform's.
    var gameID: UUID? = nil

    @State private var landscape: [TouchSkinEngine.Button] = []
    @State private var upright: [TouchSkinEngine.Button] = []
    @State private var editingPortrait = false
    @State private var opacity = TouchSkinEngine.defaultOpacity
    @State private var overlay = false
    @State private var selected: String?
    @State private var dragStart: [TouchSkinEngine.Button]?
    @State private var saveError: String?
    @State private var confirmReset = false
    @State private var exporting = false
    @State private var importing = false

    private var buttons: [TouchSkinEngine.Button] {
        get { editingPortrait ? upright : landscape }
    }

    private func setButtons(_ list: [TouchSkinEngine.Button]) {
        if editingPortrait { upright = list } else { landscape = list }
        saveError = nil
    }

    private var macros: [Macro] { state.controls.file.macros }

    /// Both orientations, the one on screen first.
    private var problems: [String] {
        let land = TouchSkinEngine.problems(in: landscape, overlay: overlay).map { "Landscape: \($0)" }
        let up = TouchSkinEngine.problems(in: upright, portrait: true, overlay: overlay).map { "Upright: \($0)" }
        return editingPortrait ? up + land : land + up
    }

    /// The layout the platform uses without a custom skin.
    private var builtInButtons: [TouchSkinEngine.Button] {
        let choice = state.platformSkins[platformID] == TouchSkinEngine.customID ? nil : state.platformSkins[platformID]
        let id = TouchSkinEngine.layoutID(game: nil, platform: choice, platformID: platformID)
        return (TouchSkinEngine.Layout.builtIn.first { $0.id == id } ?? .standard).buttons(for: platformID)
    }

    var body: some View {
        GeometryReader { geometry in
            let canvas = canvasRect(in: geometry.size)
            ZStack(alignment: .topLeading) {
                panel(canvas)
                ForEach(buttons.filter { $0.shape != .hidden }) { button in
                    control(button, canvas: canvas)
                }
            }
        }
        .background(AppTheme.letterbox.ignoresSafeArea())
        .statusBarHidden(true)
        .onAppear(perform: load)
        .confirmationDialog("Reset to the default layout?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset to Default", role: .destructive) {
                state.resetCustomSkin(platformID, gameID: gameID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(gameID == nil ? "The custom layout for \(CoreCatalog.platformName(platformID)) is deleted."
                 : "This game's own layout is deleted. It uses its system's layout again.")
        }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json,
                      defaultFilename: "\(CoreCatalog.platformName(platformID)) layout") { result in
            if case .failure(let error) = result { saveError = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in importLayout(result) }
    }

    /// The edited orientation's shape, fitted in the view, so a portrait layout can be edited on a landscape screen.
    private func canvasRect(in size: CGSize) -> CGRect {
        let shape = editingPortrait ? TouchSkinEngine.smallestPortraitCanvas : TouchSkinEngine.smallestCanvas
        let viewUpright = size.height > size.width
        guard viewUpright != editingPortrait else { return CGRect(origin: .zero, size: size) }
        let scale = min(size.width / shape.width, size.height / shape.height)
        let fitted = CGSize(width: shape.width * scale, height: shape.height * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2, width: fitted.width, height: fitted.height)
    }

    private func load() {
        let url = state.customSkinURL(platformID, gameID: gameID)
        let fallback = gameID != nil && !state.hasCustomSkin(platformID, gameID: gameID) && state.hasCustomSkin(platformID)
            ? state.customSkinURL(platformID) : url
        let saved = (try? Data(contentsOf: fallback)).flatMap { try? TouchSkinEngine.decodeFlex($0, id: platformID) }
        landscape = saved?.buttons ?? builtInButtons
        upright = saved?.portraitButtons ?? TouchSkinEngine.portrait(from: landscape)
        opacity = saved?.opacity ?? TouchSkinEngine.defaultOpacity
        overlay = saved?.overlay ?? false
        editingPortrait = UIScreen.main.bounds.height > UIScreen.main.bounds.width
    }

    private var exportDocument: SkinDocument {
        SkinDocument(data: (try? TouchSkinEngine.encodeFlex(name: "Custom", buttons: landscape, portraitButtons: upright,
                                                            opacity: opacity, overlay: overlay)) ?? Data())
    }

    /// A file from elsewhere is checked like a saved one: it must decode, and Save stays off until it passes.
    private func importLayout(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard data.count < 1_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let skin = try TouchSkinEngine.decodeFlex(data, id: platformID)
            landscape = skin.buttons
            upright = skin.portraitButtons
            opacity = skin.opacity
            overlay = skin.overlay
            selected = nil
            saveError = nil
        } catch {
            saveError = "That file is not a touch layout GagaEmu can read."
        }
    }

    // MARK: Panel

    /// The panel sits where the picture goes, so it never covers a control.
    private func panel(_ canvas: CGRect) -> some View {
        let area = editingPortrait
            ? CGRect(x: canvas.minX, y: canvas.minY, width: canvas.width, height: canvas.height * TouchSkinEngine.portraitControlTop)
            : CGRect(x: canvas.minX + canvas.width * TouchSkinEngine.controlBand, y: canvas.minY,
                     width: canvas.width * (1 - 2 * TouchSkinEngine.controlBand), height: canvas.height)
        return ScrollView { panelContent.padding(12) }
            .foregroundStyle(AppTheme.ink)
            .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: AppTheme.corner))
            .padding(8)
            .frame(width: area.width, height: area.height)
            .offset(x: area.minX, y: area.minY)
    }

    @ViewBuilder private var panelContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Edit Touch Layout").font(.screenTitle).accessibilityAddTraits(.isHeader)
            Text(gameID.flatMap { id in state.games.first { $0.id == id }?.title } ?? CoreCatalog.platformName(platformID))
                .font(.meta).foregroundStyle(AppTheme.muted)
            Picker("Orientation", selection: Binding(get: { editingPortrait }, set: { editingPortrait = $0; selected = nil })) {
                Text("Landscape").tag(false)
                Text("Upright").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)
            Text(selected.map { "Selected: \(TouchSkinEngine.editGroupName($0, in: buttons, macros: macros))" }
                 ?? "Drag a control to move it. Tap one to change it.")
                .font(.footnote)
            if let selected { selectedOptions(selected) }
            addMenu
            Rule()
            VStack(alignment: .leading, spacing: 2) {
                Text("All Controls \(Int((opacity * 100).rounded()))%").font(.footnote)
                Slider(value: $opacity, in: TouchSkinEngine.minimumOpacity...1)
                    .tint(AppTheme.accentFill)
                    .accessibilityLabel("Opacity of all controls")
                    .frame(minHeight: 44)
            }
            Toggle("Allow Over the Picture", isOn: $overlay).tint(AppTheme.accentFill).frame(minHeight: 44)
            Text(problems.first ?? saveError ?? "Ready to save.")
                .font(.footnote).foregroundStyle(problems.isEmpty && saveError == nil ? AppTheme.muted : AppTheme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
            Button("Save", action: save).buttonStyle(PrimaryButtonStyle()).disabled(!problems.isEmpty)
            HStack(spacing: 12) {
                Button("Import") { importing = true }.buttonStyle(QuietButtonStyle())
                Button("Export") { exporting = true }.buttonStyle(QuietButtonStyle())
            }
            HStack(spacing: 16) {
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle())
                Spacer(minLength: 0)
                Button("Reset to Default") { confirmReset = true }.buttonStyle(QuietButtonStyle())
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    /// Size, fade, haptic, label and, by kind, the stick's deadzone and the D-pad's corners, for the selected group.
    @ViewBuilder private func selectedOptions(_ group: String) -> some View {
        let members = buttons.filter { TouchSkinEngine.editGroup(of: $0.id) == group }
        let first = members.first
        HStack(spacing: 8) {
            Button("Smaller") { resize(0.9) }.buttonStyle(QuietButtonStyle())
            Button("Larger") { resize(1.1) }.buttonStyle(QuietButtonStyle())
            Button("Remove") { remove(group) }.buttonStyle(QuietButtonStyle())
        }
        VStack(alignment: .leading, spacing: 2) {
            Text("This Control \(Int(((first?.opacity ?? 1) * 100).rounded()))%").font(.footnote)
            Slider(value: property(group, \.opacity, default: 1), in: 0.3...1)
                .tint(AppTheme.accentFill)
                .accessibilityLabel("Opacity of this control")
                .frame(minHeight: 44)
        }
        Toggle("Haptic", isOn: property(group, \.haptic, default: true)).tint(AppTheme.accentFill).frame(minHeight: 44)
        Toggle("Show Label", isOn: property(group, \.showsLabel, default: true)).tint(AppTheme.accentFill).frame(minHeight: 44)
        if first?.shape == .stick {
            VStack(alignment: .leading, spacing: 2) {
                Text("Deadzone \(Int(((first?.deadzone ?? TouchSkinEngine.defaultDeadzone) * 100).rounded()))%").font(.footnote)
                Slider(value: property(group, \.deadzone, default: TouchSkinEngine.defaultDeadzone), in: 0...0.5)
                    .tint(AppTheme.accentFill)
                    .accessibilityLabel("Stick deadzone")
                    .frame(minHeight: 44)
            }
        }
        if group == "pad" {
            Toggle("Diagonals", isOn: Binding(get: { buttons.contains { $0.id == "upleft" } },
                                              set: { setButtons(TouchSkinEngine.withDiagonals(buttons, $0)) }))
                .tint(AppTheme.accentFill).frame(minHeight: 44)
        }
    }

    /// One setting for every member of a group; optional values read their default when unset.
    private func property<Value>(_ group: String, _ path: WritableKeyPath<TouchSkinEngine.Button, Value?>, default fallback: Value) -> Binding<Value> {
        Binding(get: { buttons.first { TouchSkinEngine.editGroup(of: $0.id) == group }?[keyPath: path] ?? fallback },
                set: { value in setButtons(buttons.map { var b = $0; if TouchSkinEngine.editGroup(of: b.id) == group { b[keyPath: path] = value }; return b }) })
    }

    private func property(_ group: String, _ path: WritableKeyPath<TouchSkinEngine.Button, Bool>, default fallback: Bool) -> Binding<Bool> {
        Binding(get: { buttons.first { TouchSkinEngine.editGroup(of: $0.id) == group }?[keyPath: path] ?? fallback },
                set: { value in setButtons(buttons.map { var b = $0; if TouchSkinEngine.editGroup(of: b.id) == group { b[keyPath: path] = value }; return b }) })
    }

    /// The palette: the core's buttons, sticks, app functions, turbo and macros.
    private var addMenu: some View {
        Menu {
            Menu("Button") {
                ForEach(ControlAction.coreButtons, id: \.mask) { item in Button(item.name) { add(.buttons(item.mask)) } }
            }
            Menu("Stick") {
                Button("Left Stick") { add(nil, stick: "lstick") }
                Button("Right Stick") { add(nil, stick: "rstick") }
            }
            Menu("App Function") {
                ForEach(AppFunction.allCases) { function in Button(function.title) { add(.app(function)) } }
            }
            Menu("Turbo (Hold)") {
                ForEach(ControlAction.coreButtons, id: \.mask) { item in Button(item.name) { add(.turbo(item.mask, toggle: false)) } }
            }
            Menu("Turbo (Toggle)") {
                ForEach(ControlAction.coreButtons, id: \.mask) { item in Button(item.name) { add(.turbo(item.mask, toggle: true)) } }
            }
            if !macros.isEmpty {
                Menu("Macro") {
                    ForEach(macros) { macro in Button(macro.name) { add(.macro(macro.id)) } }
                }
            }
        } label: {
            Label("Add Control", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(QuietButtonStyle())
    }

    private func add(_ action: ControlAction?, stick: String? = nil) {
        if let stick, buttons.contains(where: { $0.id == stick }) { return }
        let element = TouchSkinEngine.newElement(action, stick: stick, in: buttons, portrait: editingPortrait)
        setButtons(buttons + [element])
        selected = element.id
    }

    private func remove(_ group: String) {
        setButtons(buttons.filter { TouchSkinEngine.editGroup(of: $0.id) != group })
        selected = nil
    }

    private func save() {
        do {
            try state.saveCustomSkin(landscape, portraitButtons: upright, opacity: opacity, overlay: overlay,
                                     platformID: platformID, gameID: gameID)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: Controls

    private func control(_ button: TouchSkinEngine.Button, canvas: CGRect) -> some View {
        let group = TouchSkinEngine.editGroup(of: button.id)
        let isSelected = selected == group
        let name = TouchSkinEngine.label(for: button, macros: macros)
        return glyph(button, label: button.showsLabel ? name.glyph : nil, selected: isSelected)
            .opacity(opacity * (button.opacity ?? 1))
            .frame(width: button.frame.width * canvas.width, height: button.frame.height * canvas.height)
            .contentShape(Rectangle())
            .position(x: canvas.minX + button.frame.midX * canvas.width, y: canvas.minY + button.frame.midY * canvas.height)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = buttons
                        selected = group
                        saveError = nil
                    }
                    guard let start = dragStart else { return }
                    setButtons(TouchSkinEngine.moving(start, group: group, by: CGSize(width: value.translation.width / canvas.width,
                                                                                      height: value.translation.height / canvas.height)))
                }
                .onEnded { _ in dragStart = nil })
            .accessibilityElement()
            .accessibilityLabel(name.spoken)
            .accessibilityValue(isSelected ? "Selected" : "")
            .accessibilityHint("Drag to move. Actions move and size \(TouchSkinEngine.editGroupName(group, in: buttons, macros: macros)).")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { selected = group }
            .accessibilityAction(named: "Move Left") { nudge(group, -0.02, 0) }
            .accessibilityAction(named: "Move Right") { nudge(group, 0.02, 0) }
            .accessibilityAction(named: "Move Up") { nudge(group, 0, -0.04) }
            .accessibilityAction(named: "Move Down") { nudge(group, 0, 0.04) }
            .accessibilityAction(named: "Larger") { selected = group; resize(1.1) }
            .accessibilityAction(named: "Smaller") { selected = group; resize(0.9) }
            .accessibilityAction(named: "Remove") { remove(group) }
    }

    @ViewBuilder private func glyph(_ button: TouchSkinEngine.Button, label: String?, selected: Bool) -> some View {
        let content = selected ? AppTheme.onAccent : AppTheme.onLetterbox
        let fill = selected ? AppTheme.accentFill : Color.clear
        if button.shape == .circle || button.shape == .stick {
            Circle().fill(fill)
                .overlay(Circle().stroke(AppTheme.onLetterbox, lineWidth: selected ? 2 : 1))
                .overlay(Text(label ?? "").font(.system(.headline, design: .serif)).lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(content))
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
        setButtons(TouchSkinEngine.resizing(buttons, group: selected, by: factor))
    }

    private func nudge(_ group: String, _ dx: CGFloat, _ dy: CGFloat) {
        selected = group
        setButtons(TouchSkinEngine.moving(buttons, group: group, by: CGSize(width: dx, height: dy)))
    }
}
