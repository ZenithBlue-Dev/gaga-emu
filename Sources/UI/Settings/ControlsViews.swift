import SwiftUI

/// Touch Layout, Controller Mapping, Macros, Turbo and Players, from Settings > Controls (no game) or the pause
/// menu (this game). With a game, layout and mapping offer the game's own override.
struct ControlsSheet: View {
    @EnvironmentObject private var state: AppState
    var game: GameItem?
    var session: GameSession?
    @State private var page: Page?
    @State private var editing: EditTarget?

    enum Page: String, Identifiable { case mapping, macros, turbo, players; var id: String { rawValue } }
    private struct EditTarget: Identifiable { let id: String; let gameID: UUID? }

    var body: some View {
        PaperSheet(title: "Controls", subtitle: game?.title) {
            VStack(alignment: .leading, spacing: 20) {
                if let game {
                    GroupCard(title: "Touch Controls") {
                        // The skin this game plays with, drawn as it shows in game.
                        CurrentSkinPicture(platformID: game.platformID, game: game, labelled: true)
                            .frame(maxWidth: 320, maxHeight: 160)
                            .padding(.vertical, 8)
                        Rule()
                        row("Touch Layout", "This system") { editing = EditTarget(id: game.platformID, gameID: nil) }
                        Rule()
                        row("Touch Layout", state.hasCustomSkin(game.platformID, gameID: game.id) ? "This game, edited" : "This game only") {
                            editing = EditTarget(id: game.platformID, gameID: game.id)
                        }
                    }
                }
                GroupCard(title: "Controllers") {
                    row("Controller Mapping", nil) { page = .mapping }
                    Rule()
                    row("Players", nil) { page = .players }
                }
                GroupCard(title: "Macros and Turbo") {
                    row("Macros", "\(state.controls.file.macros.count)") { page = .macros }
                    Rule()
                    row("Turbo", "\(Int(state.controls.file.turboHertz)) per second") { page = .turbo }
                }
                GroupCard(title: "Feel and Style") { ControlOptions(game: game).padding(.vertical, 4) }
            }
        }
        .sheet(item: $page) { page in
            switch page {
            case .mapping: ControllerMappingView(platformID: game?.platformID, game: game)
            case .macros: MacrosView()
            case .turbo: TurboView()
            case .players: PlayersView(platformID: game?.platformID, session: session)
            }
        }
        .fullScreenCover(item: $editing, onDismiss: reloadSkin) { SkinEditorView(platformID: $0.id, gameID: $0.gameID) }
        .onChange(of: state.controls.file.skinStyle) { reloadSkin() }
        .onChange(of: state.controls.file.skinVariant) { reloadSkin() }
    }

    /// A layout saved from the pause menu shows in the running game at once.
    private func reloadSkin() {
        guard let game, session != nil else { return }
        let upright = state.skins.portrait
        state.applySkin(for: game)
        state.skins.portrait = upright
    }

    private func row(_ title: String, _ value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer(minLength: 12)
                if let value { Text(value).font(.meta).foregroundStyle(AppTheme.muted) }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
            }
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Haptic strength, hiding touch with a controller, and a game's orientation lock.
struct ControlOptions: View {
    @EnvironmentObject private var state: AppState
    private var file: Binding<ControlsStore.File> { state.controlsFile }
    var game: GameItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Touch Haptics")
                Spacer(minLength: 12)
                Picker("Touch Haptics", selection: file.touchHaptics) {
                    ForEach(HapticStrength.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .onChange(of: state.controls.file.touchHaptics) { state.skins.hapticStrength = state.controls.file.touchHaptics }
            }
            .frame(minHeight: 44)
            Text("A press, a release and each new D-pad direction feel different. Game rumble is set apart.")
                .font(.footnote).foregroundStyle(AppTheme.muted)
            Rule().padding(.vertical, 4)
            Toggle(isOn: file.hideTouchWithController) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hide Touch With a Controller")
                    Text("Touch controls go away once a controller sends input.").font(.footnote).foregroundStyle(AppTheme.muted)
                }
            }
            .tint(AppTheme.accentFill)
            .frame(minHeight: 44)
            if let game {
                Rule().padding(.vertical, 4)
                HStack {
                    Text("Orientation")
                    Spacer(minLength: 12)
                    Picker("Orientation", selection: orientation(game)) {
                        Text("Auto").tag("")
                        Text("Upright").tag("portrait")
                        Text("Landscape").tag("landscape")
                    }
                    .labelsHidden()
                }
                .frame(minHeight: 44)
                Rule().padding(.vertical, 4)
                SkinStyleRows(platformID: game.platformID, game: game)
            }
        }
    }

    private func orientation(_ game: GameItem) -> Binding<String> {
        Binding(get: { state.controls.file.orientation[game.id.uuidString] ?? "" },
                set: { value in
                    state.controls.file.orientation[game.id.uuidString] = value.isEmpty ? nil : value
                    OrientationLock.set(value.isEmpty ? nil : value)
                })
    }
}

/// Skin Style for a system and, with a game, that game's own choice, plus the device skin's colour. Default is
/// Classic. Device skins are fixed layouts: the layout editor changes the Classic skin only.
struct SkinStyleRows: View {
    @EnvironmentObject private var state: AppState
    let platformID: String
    var game: GameItem?

    /// The game's choice; empty is the system's.
    private static let sameAsSystem = ""

    var body: some View {
        if TouchSkinEngine.hasDevice(platformID) {
            VStack(alignment: .leading, spacing: 0) {
                row(game == nil ? "Skin Style" : "Skin Style, This System", selection: style("platform:\(platformID)", fallback: SkinStyle.classic.rawValue)) {
                    ForEach(SkinStyle.allCases) { Text($0.title).tag($0.rawValue) }
                }
                if let game {
                    row("Skin Style, This Game", selection: style("game:\(game.id.uuidString)", fallback: Self.sameAsSystem)) {
                        Text("Same as System").tag(Self.sameAsSystem)
                        ForEach(SkinStyle.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }
                if usesDevice {
                    row("Skin Colour", selection: colour) {
                        Text("Standard").tag("")
                        ForEach(TouchSkinEngine.deviceVariants(platformID), id: \.self) { Text($0).tag($0) }
                    }
                    Text("Device skins are fixed layouts. The layout editor changes the Classic skin.")
                        .font(.footnote).foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// The colour row shows while this system or this game uses Device.
    private var usesDevice: Bool {
        let file = state.controls.file
        return file.style(platformID: platformID, gameID: nil) == .device
            || game.map { file.style(platformID: platformID, gameID: $0.id) == .device } == true
    }

    private func row<Content: View>(_ title: String, selection: Binding<String>, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Picker(title, selection: selection, content: content).labelsHidden()
        }
        .frame(minHeight: 44)
    }

    /// Classic and the game's Same as System are stored as no entry.
    private func style(_ key: String, fallback: String) -> Binding<String> {
        Binding(get: { state.controls.file.skinStyle[key] ?? fallback },
                set: { state.controls.file.skinStyle[key] = $0 == fallback || $0.isEmpty ? nil : $0 })
    }

    private var colour: Binding<String> {
        Binding(get: { state.controls.file.skinVariant[platformID] ?? "" },
                set: { state.controls.file.skinVariant[platformID] = $0.isEmpty ? nil : $0 })
    }
}

// MARK: - Controller mapping

/// Any controller input or combo to any core button, app function, turbo or macro, per platform and controller
/// type, with a game's own override. Edits apply to the next frame of a running game.
struct ControllerMappingView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var controllers: ControllerManager
    @State private var platformID: String
    @State private var kind: ControllerManager.Kind = .mfi
    @State private var gameOnly = false
    @State private var adding: [PadInput] = []
    let game: GameItem?

    init(platformID: String?, game: GameItem?) {
        _platformID = State(initialValue: platformID ?? CoreCatalog.platforms.first?.id ?? "")
        self.game = game
    }

    static let kinds: [ControllerManager.Kind] = [.mfi, .xbox, .dualSense, .dualShock4, .joyConPair, .unknown, .keyboard]

    private var key: String {
        if gameOnly, let game { return ControlsStore.key(gameID: game.id, kind: kind) }
        return ControlsStore.key(platformID: platformID, kind: kind)
    }

    private var profile: PadProfile {
        state.controls.file.pads[key] ?? state.controls.profile(kind: kind, platformID: platformID, gameID: gameOnly ? game?.id : nil)
    }

    private func update(_ change: (inout PadProfile) -> Void) {
        var copy = profile
        change(&copy)
        state.controls.file.pads[key] = copy.normalized()
    }

    var body: some View {
        PaperSheet(title: "Controller Mapping", subtitle: game?.title) {
            VStack(alignment: .leading, spacing: 8) {
                if game == nil {
                    Picker("System", selection: $platformID) {
                        ForEach(CoreCatalog.platforms) { Text($0.name).tag($0.id) }
                    }
                    .frame(minHeight: 44)
                } else {
                    Toggle("This Game Only", isOn: $gameOnly).tint(AppTheme.accentFill).frame(minHeight: 44)
                }
                Picker("Controller", selection: $kind) {
                    ForEach(Self.kinds, id: \.self) { Text($0.label).tag($0) }
                }
                .frame(minHeight: 44)
                Text("Each controller type keeps its own mapping. A game's own mapping wins over its system's.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
                Rule()
                if kind == .keyboard {
                    KeyboardMappingRows(platformID: platformID, gameID: gameOnly ? game?.id : nil)
                } else {
                    padRows
                }
            }
        }
        .onAppear {
            if let first = controllers.devices.first(where: { !$0.isTouch }) { kind = first.kind }
            if let game {
                gameOnly = ControllerManager.Kind.allKinds.contains { state.controls.file.pads[ControlsStore.key(gameID: game.id, kind: $0)] != nil }
                    || state.controls.file.keys[ControlsStore.keyboardKey(gameID: game.id)] != nil
            }
        }
    }

    @ViewBuilder private var padRows: some View {
        ForEach(profile.bindings) { binding in bindingRow(binding) }
        Rule()
        newBinding
        Rule()
        Toggle("Left Stick Moves the D-pad", isOn: Binding(get: { profile.stickAsDpad }, set: { v in update { $0.stickAsDpad = v } }))
            .tint(AppTheme.accentFill).frame(minHeight: 44)
        Toggle("Hold Menu to Open Pause Menu", isOn: Binding(get: { profile.menuHold > 0 }, set: { v in update { $0.menuHold = v ? 1 : 0 } }))
            .tint(AppTheme.accentFill).frame(minHeight: 44)
        if profile.menuHold > 0 {
            slider("Hold Time", value: Binding(get: { profile.menuHold }, set: { v in update { $0.menuHold = v } }),
                   range: PadProfile.menuHoldRange, text: String(format: "%.1f s", profile.menuHold))
        }
        Text("Home opens the pause menu where iOS passes it through. Holding Menu does too: a short press is still Start.")
            .font(.footnote).foregroundStyle(AppTheme.muted)
        slider("Deadzone", value: Binding(get: { profile.deadzone }, set: { v in update { $0.deadzone = v } }),
               range: PadProfile.deadzoneRange, text: "\(Int((profile.deadzone * 100).rounded()))%")
        slider("Sensitivity", value: Binding(get: { profile.sensitivity }, set: { v in update { $0.sensitivity = v } }),
               range: PadProfile.sensitivityRange, text: String(format: "%.1fx", profile.sensitivity))
        Button("Reset to Defaults") { state.controls.file.pads[key] = nil }
            .buttonStyle(QuietButtonStyle())
            .frame(minHeight: 44)
    }

    private func bindingRow(_ binding: PadBinding) -> some View {
        HStack {
            Text(binding.inputs.map { $0.title(for: kind) }.joined(separator: " + "))
            Spacer(minLength: 8)
            Menu(binding.action.title(macros: state.controls.file.macros)) {
                ActionChoices(macros: state.controls.file.macros) { action in
                    update { profile in
                        if let index = profile.bindings.firstIndex(where: { $0.id == binding.id }) { profile.bindings[index].action = action }
                    }
                }
            }
            .foregroundStyle(AppTheme.accent)
            Button { update { $0.bindings.removeAll { $0.id == binding.id } } } label: {
                Image(systemName: "minus.circle").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(binding.inputs.map { $0.title(for: kind) }.joined(separator: " and "))")
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
    }

    /// Pick one input, or several for a combo, then what it does.
    private var newBinding: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add a Mapping").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text(adding.isEmpty ? "Choose one input, or more for a combo." : adding.map { $0.title(for: kind) }.joined(separator: " + "))
                .font(.footnote).foregroundStyle(AppTheme.muted)
            HStack {
                Menu("Input") {
                    ForEach(PadInput.allCases.filter { !adding.contains($0) }) { input in
                        Button(input.title(for: kind)) { adding.append(input) }
                    }
                }
                .foregroundStyle(AppTheme.accent)
                .frame(minHeight: 44)
                Spacer()
                if !adding.isEmpty {
                    Menu("Does") {
                        ActionChoices(macros: state.controls.file.macros) { action in
                            let inputs = adding
                            update { $0.bindings.append(PadBinding(inputs: inputs, action: action)) }
                            adding = []
                        }
                    }
                    .foregroundStyle(AppTheme.accent)
                    Button("Clear") { adding = [] }.buttonStyle(QuietButtonStyle())
                }
            }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(title); Spacer(); Text(text).font(.meta).foregroundStyle(AppTheme.muted) }
            Slider(value: value, in: range).tint(AppTheme.accentFill).accessibilityLabel(title).accessibilityValue(text)
        }
        .frame(minHeight: 44)
    }
}

/// The hardware keyboard: any key to a core button, app function, turbo or macro, for a system or one game. It plays
/// as player 1. A computer system passes keys straight to the game unless Pass-Through is off.
struct KeyboardMappingRows: View {
    @EnvironmentObject private var state: AppState
    let platformID: String
    let gameID: UUID?

    private var key: String { gameID.map(ControlsStore.keyboardKey(gameID:)) ?? ControlsStore.keyboardKey(platformID: platformID) }
    private var profile: KeyProfile { state.controls.file.keys[key] ?? ControlsStore.keyProfile(in: state.controls.file, platformID: platformID, gameID: gameID) }

    private func update(_ change: (inout KeyProfile) -> Void) {
        var copy = profile
        change(&copy)
        state.controls.file.keys[key] = copy
    }

    var body: some View {
        if GameSession.typingPlatforms.contains(platformID) {
            Toggle(isOn: Binding(get: { profile.passThrough }, set: { v in update { $0.passThrough = v } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keyboard Pass-Through")
                    Text("The game reads every key as typed, and the mappings below wait until this is off.")
                        .font(.footnote).foregroundStyle(AppTheme.muted)
                }
            }
            .tint(AppTheme.accentFill)
            .frame(minHeight: 44)
            Rule()
        }
        ForEach(profile.bindings) { binding in
            HStack {
                Text(KeyProfile.name(binding.key))
                Spacer(minLength: 8)
                Menu(binding.action.title(macros: state.controls.file.macros)) {
                    ActionChoices(macros: state.controls.file.macros) { action in
                        update { profile in
                            if let index = profile.bindings.firstIndex(where: { $0.id == binding.id }) { profile.bindings[index].action = action }
                        }
                    }
                }
                .foregroundStyle(AppTheme.accent)
                Button { update { $0.bindings.removeAll { $0.id == binding.id } } } label: {
                    Image(systemName: "minus.circle").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(KeyProfile.name(binding.key))")
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .contain)
        }
        Rule()
        Menu("Add a Key") {
            ForEach(KeyProfile.keys.filter { key in !profile.bindings.contains { $0.key == key.usage } }, id: \.usage) { key in
                Menu(key.name) {
                    ActionChoices(macros: state.controls.file.macros) { action in
                        update { $0.bindings.append(KeyBinding(key: key.usage, action: action)) }
                    }
                }
            }
        }
        .foregroundStyle(AppTheme.accent)
        .frame(minHeight: 44)
        Button("Reset to Defaults") { state.controls.file.keys[key] = nil }
            .buttonStyle(QuietButtonStyle())
            .frame(minHeight: 44)
    }
}

extension AppState {
    /// A binding into Controls.json, which saves on each change.
    var controlsFile: Binding<ControlsStore.File> {
        Binding(get: { self.controls.file }, set: { self.controls.file = $0 })
    }
}

extension ControllerManager.Kind {
    static let allKinds: [ControllerManager.Kind] = [.touch, .keyboard, .mfi, .dualShock4, .dualSense, .xbox, .joyConPair, .joyConLeft, .joyConRight, .unknown]
}

/// Menu entries for every action: core buttons, app functions, turbo and macros.
struct ActionChoices: View {
    let macros: [Macro]
    let choose: (ControlAction) -> Void

    var body: some View {
        Menu("Button") {
            ForEach(ControlAction.coreButtons, id: \.mask) { item in Button(item.name) { choose(.buttons(item.mask)) } }
        }
        Menu("App Function") {
            ForEach(AppFunction.allCases) { function in Button(function.title) { choose(.app(function)) } }
        }
        Menu("Turbo (Hold)") {
            ForEach(ControlAction.coreButtons, id: \.mask) { item in Button(item.name) { choose(.turbo(item.mask, toggle: false)) } }
        }
        Menu("Turbo (Toggle)") {
            ForEach(ControlAction.coreButtons, id: \.mask) { item in Button(item.name) { choose(.turbo(item.mask, toggle: true)) } }
        }
        if !macros.isEmpty {
            Menu("Macro") {
                ForEach(macros) { macro in Button(macro.name) { choose(.macro(macro.id)) } }
            }
        }
    }
}

// MARK: - Macros

/// Named macros. Record one from the pause menu, or write one here step by step.
struct MacrosView: View {
    @EnvironmentObject private var state: AppState
    @State private var editing: Macro?

    var body: some View {
        PaperSheet(title: "Macros") {
            VStack(alignment: .leading, spacing: 0) {
                Text("A macro plays its steps frame by frame. Put one on a touch control or a controller button. Pausing stops it. Record one from the pause menu with Record Macro.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).padding(.bottom, 8)
                ForEach(state.controls.file.macros) { macro in
                    Button { editing = macro } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(macro.name)
                                Text("\(macro.steps.count) steps, \(macro.steps.reduce(0) { $0 + $1.frames }) frames\(macro.loops ? ", loops" : "")")
                                    .font(.footnote).foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    Rule()
                }
                Button("New Macro") {
                    editing = Macro(name: "Macro \(state.controls.file.macros.count + 1)",
                                    steps: [.init(buttons: ControllerManager.Button.south, frames: 2)])
                }
                .buttonStyle(QuietButtonStyle())
                .frame(minHeight: 44)
            }
        }
        .sheet(item: $editing) { MacroEditor(macro: $0) }
    }
}

struct MacroEditor: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State var macro: Macro

    var body: some View {
        PaperSheet(title: "Macro") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: $macro.name).textFieldStyle(.roundedBorder).frame(minHeight: 44)
                Toggle("Repeat Until Pressed Again", isOn: $macro.loops).tint(AppTheme.accentFill).frame(minHeight: 44)
                Rule()
                ForEach(macro.steps.indices, id: \.self) { index in stepRow(index) }
                Button("Add Step") { macro.steps.append(.init(buttons: 0, frames: 2)) }
                    .buttonStyle(QuietButtonStyle()).frame(minHeight: 44)
                Rule()
                Button("Save") { save() }.buttonStyle(PrimaryButtonStyle()).disabled(macro.name.isEmpty || macro.steps.isEmpty)
                Button("Delete Macro", role: .destructive) {
                    state.controls.file.macros.removeAll { $0.id == macro.id }
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle())
                .frame(minHeight: 44)
            }
        }
    }

    private func stepRow(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Step \(index + 1)").font(.subheadline.weight(.semibold))
                Spacer()
                Button { macro.steps.remove(at: index) } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove step \(index + 1)")
            }
            Menu(ControlAction.buttonNames(macro.steps[index].buttons)) {
                ForEach(ControlAction.coreButtons, id: \.mask) { item in
                    let on = macro.steps[index].buttons & item.mask != 0
                    Button { macro.steps[index].buttons ^= item.mask } label: {
                        if on { Label(item.name, systemImage: "checkmark") } else { Text(item.name) }
                    }
                }
            }
            .foregroundStyle(AppTheme.accent)
            .frame(minHeight: 44)
            .accessibilityLabel("Buttons held: \(ControlAction.buttonNames(macro.steps[index].buttons))")
            Stepper("Hold for \(macro.steps[index].frames) frames", value: $macro.steps[index].frames, in: 1...Macro.maxFrames)
                .frame(minHeight: 44)
        }
    }

    private func save() {
        if let index = state.controls.file.macros.firstIndex(where: { $0.id == macro.id }) {
            state.controls.file.macros[index] = macro
        } else {
            state.controls.file.macros.append(macro)
        }
        dismiss()
    }
}

// MARK: - Turbo

struct TurboView: View {
    @EnvironmentObject private var state: AppState
    private var file: Binding<ControlsStore.File> { state.controlsFile }
    @State private var showTriggerPro = false

    var body: some View {
        PaperSheet(title: "Turbo") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Turbo presses a button on and off while you hold it, or, as a toggle, until you press it again. Put Turbo on a touch control in the layout editor, or on a controller button in Controller Mapping. Timing counts game frames, so it holds at any speed.")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
                VStack(alignment: .leading, spacing: 2) {
                    HStack { Text("Rate"); Spacer(); Text("\(Int(state.controls.file.turboHertz)) presses per second").font(.meta).foregroundStyle(AppTheme.muted) }
                    Slider(value: file.turboHertz, in: FrameInputProcessor.hertzRange, step: 1)
                        .tint(AppTheme.accentFill)
                        .accessibilityLabel("Turbo rate")
                        .accessibilityValue("\(Int(state.controls.file.turboHertz)) per second")
                }
                .frame(minHeight: 44)
                Rule()
                Stepper("Fast Forward Button: \(state.controls.file.fastForwardSpeed)x", value: file.fastForwardSpeed, in: 2...5)
                    .frame(minHeight: 44)
                Rule()
                Button("Hold Latch and Combos (TriggerPro)") { showTriggerPro = true }
                    .buttonStyle(QuietButtonStyle())
                    .frame(minHeight: 44)
            }
        }
        .sheet(isPresented: $showTriggerPro) { TriggerProEditor() }
    }
}

// MARK: - Players

/// Which controller plays as which player. New controllers take the next free player as they connect; touch is
/// always Player 1 until a controller there sends input.
struct PlayersView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var controllers: ControllerManager
    var platformID: String?
    /// The running game, which takes a Multitap change from its next frame.
    var session: GameSession?

    var body: some View {
        PaperSheet(title: "Players") {
            VStack(alignment: .leading, spacing: 0) {
                if let platformID {
                    let count = session?.maxPlayers ?? CoreCatalog.maxPlayers(platformID)
                    Text("\(CoreCatalog.platformName(platformID)) takes \(count) \(count == 1 ? "player" : "players"). Controllers past that are not read.")
                        .font(.footnote).foregroundStyle(AppTheme.muted).padding(.bottom, 8)
                }
                ForEach((platformID.map { [$0] } ?? CoreCatalog.platforms.map(\.id)).filter(CoreCatalog.hasMultitap), id: \.self) { id in
                    HStack {
                        Text(platformID == nil ? "Multitap: \(CoreCatalog.platformName(id))" : "Multitap")
                        Spacer(minLength: 12)
                        Picker("Multitap", selection: multitap(id)) {
                            ForEach(MultitapMode.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                    }
                    .frame(minHeight: 44)
                    Rule()
                }
                if (platformID.map { [$0] } ?? CoreCatalog.platforms.map(\.id)).contains(where: CoreCatalog.hasMultitap) {
                    Text("A multitap adds players 3 to 5. Auto plugs it in once a controller is Player 3 or later. If a game misreads its controllers with it in, choose Off.")
                        .font(.footnote).foregroundStyle(AppTheme.muted).padding(.vertical, 8)
                }
                HStack {
                    Text("Touch Controls")
                    Spacer()
                    Text(controllers.touchOwnsPlayerOne ? "Player 1" : "Off while a controller is Player 1").font(.meta).foregroundStyle(AppTheme.muted)
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
                Rule()
                ForEach(controllers.devices) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                            Text(device.kind.label).font(.footnote).foregroundStyle(AppTheme.muted)
                        }
                        Spacer(minLength: 12)
                        Menu(device.slot.map { "Player \($0 + 1)" } ?? "Unassigned") {
                            ForEach(0..<ControllerManager.slotCount, id: \.self) { index in
                                Button("Player \(index + 1)") { controllers.assign(device.id, to: index) }
                            }
                            Button("Unassign") { controllers.assign(device.id, to: nil) }
                        }
                        .foregroundStyle(AppTheme.accent)
                        .frame(minHeight: 44)
                        .accessibilityLabel("\(device.name) player")
                        .accessibilityValue(device.slot.map { "Player \($0 + 1)" } ?? "Unassigned")
                    }
                    Rule()
                }
                if controllers.devices.isEmpty {
                    Text("No controllers connected. Pair one in iOS Settings; it joins as the next player, even mid-game.")
                        .font(.footnote).foregroundStyle(AppTheme.muted).padding(.top, 8)
                }
            }
        }
    }

    /// Auto is stored as no entry.
    private func multitap(_ id: String) -> Binding<MultitapMode> {
        Binding(get: { ControlsStore.multitap(in: state.controls.file, platformID: id) },
                set: { mode in
                    state.controls.file.multitap[id] = mode == .auto ? nil : mode.rawValue
                    if let session, session.game.platformID == id { session.setMultitap(mode) }
                })
    }
}
