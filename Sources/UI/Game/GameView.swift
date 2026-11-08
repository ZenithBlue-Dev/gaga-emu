import MetalKit
import SwiftUI

/// Picture centred on ink, touch controls in the bands left and right of it, pause menu on top.
struct GameView: View {
    @ObservedObject var session: GameSession
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var controllers: ControllerManager
    @EnvironmentObject private var skins: TouchSkinEngine
    @ObservedObject private var external = ExternalDisplay.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dropTargeted = false

    private var touchVisible: Bool { controllers.touchOwnsPlayerOne }

    var body: some View {
        GeometryReader { geometry in
            // Between Controls keeps the picture out of the bands (and the safe area beside them); Full Screen and a
            // custom two-screen layout use the whole display, under the controls.
            let custom = session.isDualScreen && session.screen.preset == .custom
            let reserveBands = (touchVisible || !state.autoFullScreen) && session.screen.area == .betweenControls && !custom
            ZStack(alignment: .topLeading) {
                if external.showsPicture {
                    Text("The picture is on the other screen.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.onLetterbox)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GamePicture(session: session, takesTouch: true)
                        .padding(.horizontal, reserveBands ? geometry.size.width * TouchSkinEngine.controlBand : 0)
                        .ignoresSafeArea(edges: reserveBands ? .vertical : .all)
                        .accessibilityElement()
                        .accessibilityLabel("\(session.game.title), game picture")
                        .accessibilityAddTraits(.isImage)
                }
                if touchVisible { TouchControls(session: session, skins: skins) }
                HStack(spacing: 0) {
                    pauseButton
                    Spacer(minLength: 0)
                    if session.isDualScreen { swapButton }
                    if session.rewindStatus == .ready { rewindButton }
                    fastForwardButton
                }
                if session.touchScreenHidden {
                    Text("Bottom screen hidden. Touch input is off.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.onLetterbox)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppTheme.letterbox.opacity(0.7), in: RoundedRectangle(cornerRadius: AppTheme.corner))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 4)
                        .allowsHitTesting(false)
                }
            }
        }
        .overlay {
            if session.menuOpen {
                PauseMenu(session: session)
                    .transition(.opacity)
            }
        }
        .alert(session.notice ?? "", isPresented: Binding(get: { session.notice != nil }, set: { if !$0 { session.notice = nil } })) {
            Button("OK", role: .cancel) {}
        }
        // A file dropped on the game goes to the Library; the game keeps running.
        .gameFileDrop(isTargeted: $dropTargeted) { line, _ in session.notice = line }
        .dropHighlight(dropTargeted)
        .unplacedQuestion()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: session.menuOpen)
        .background(AppTheme.letterbox.ignoresSafeArea())
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onChange(of: touchVisible) { session.clearTouches() }
        .onAppear {
            external.present(state.airPlayFullscreen ? session : nil)
            session.run()
        }
        .onDisappear { external.present(nil) }
    }

    private var pauseButton: some View {
        Button { session.pause(.menu) } label: {
            Image(systemName: "pause.fill")
                .foregroundStyle(AppTheme.onLetterbox)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .opacity(0.8)
        .accessibilityLabel("Pause game")
    }

    /// Exchanges the two screens, or shows the other one in One Screen.
    private var swapButton: some View {
        Button { session.swapScreens() } label: {
            Image(systemName: "arrow.up.arrow.down.square")
                .foregroundStyle(AppTheme.onLetterbox)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .opacity(0.8)
        .accessibilityLabel("Swap screens")
        .accessibilityHint(session.screen.preset == .single ? "Shows the other screen." : "Exchanges the top and bottom screens.")
    }

    /// Rewinds while a finger stays on it. Filled while it runs, with the word, so colour is not the only cue.
    private var rewindButton: some View {
        let on = session.rewinding
        return Group {
            if on {
                Text("Back").font(.meta.weight(.bold)).foregroundStyle(AppTheme.onAccent)
            } else {
                Image(systemName: "backward.fill").foregroundStyle(AppTheme.onLetterbox)
            }
        }
        .frame(width: 44, height: 44)
        .background(on ? AppTheme.accentFill : Color.clear, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        .contentShape(Rectangle())
        .opacity(on ? 1 : 0.8)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !session.rewinding { session.setRewindHeld(true) } }
            .onEnded { _ in session.setRewindHeld(false) })
        .accessibilityElement()
        .accessibilityLabel("Rewind")
        .accessibilityHint("Hold to step back. Activating rewinds one second.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { session.rewindForAccessibility() }
    }

    /// Text replaces the glyph while it runs, so colour is not the only cue.
    private var fastForwardButton: some View {
        let on = session.fastForward > 1
        return Button { session.toggleFastForward() } label: {
            Group {
                if on {
                    Text("\(session.fastForward)x").font(.meta.weight(.bold)).foregroundStyle(AppTheme.onAccent)
                } else {
                    Image(systemName: "forward.fill").foregroundStyle(AppTheme.onLetterbox)
                }
            }
            .frame(width: 44, height: 44)
            .background(on ? AppTheme.accentFill : Color.clear, in: RoundedRectangle(cornerRadius: AppTheme.corner))
            .contentShape(Rectangle())
        }
        .opacity(on ? 1 : 0.8)
        .accessibilityLabel("Fast forward")
        .accessibilityValue(on ? "\(session.fastForward) times speed" : "Off")
    }
}

struct GamePicture: View {
    @ObservedObject var session: GameSession
    /// The device's own picture, where a finger can land. Not the external screen's.
    var takesTouch = false

    var body: some View {
        if session.drawsOwnPicture && !session.filtersLayerCore {
            LayerPicture(session: session, takesTouch: takesTouch)
        } else {
            MetalPicture(session: session, takesTouch: takesTouch)
        }
    }
}

/// A 2D core's frames, drawn by the renderer through the filter chain.
private struct MetalPicture: UIViewRepresentable {
    @ObservedObject var session: GameSession
    var takesTouch: Bool

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: session.renderer.device)
        if takesTouch { session.pictureView = view }
        view.delegate = session.renderer
        view.colorPixelFormat = MetalRenderer.outputPixelFormat
        if let layer = view.layer as? CAMetalLayer { MetalRenderer.configureOutput(layer) }
        view.clearColor = MetalRenderer.letterboxColor
        view.preferredFramesPerSecond = Int(session.targetFPS.rounded(.up))
        return view
    }

    /// No draws while paused, which also keeps GPU work out of the background.
    func updateUIView(_ view: MTKView, context: Context) {
        view.isPaused = session.phase != .running && session.phase != .prepared
    }
}

/// A layer-path core's picture: the core presents to this view's CAMetalLayer itself, so no filter runs.
/// The core stops stepping while paused, which keeps GPU work out of the background.
private struct LayerPicture: UIViewRepresentable {
    @ObservedObject var session: GameSession
    var takesTouch: Bool

    func makeUIView(context: Context) -> MetalLayerView {
        let view = MetalLayerView()
        view.session = session
        if takesTouch { session.pictureView = view }
        return view
    }

    func updateUIView(_ view: MetalLayerView, context: Context) {
        view.place(content: session.frameSize, scaling: session.screen.scaling)
    }

    static func dismantleUIView(_ view: MetalLayerView, coordinator: ()) { view.detach() }
}

/// Holds the layer the core presents to, sized and placed by the scaling mode (docs/05 section 2.6). The core
/// fits its frame in the layer's drawable, so the drawable keeps the frame's shape and Stretch is the layer
/// drawn at another shape. Zoom's overflow is clipped here.
final class MetalLayerView: UIView {
    private final class Surface: UIView {
        override class var layerClass: AnyClass { CAMetalLayer.self }
    }

    weak var session: GameSession?
    private let surface = Surface()
    private var attachedSize: CGSize = .zero
    private var content: CGSize?
    private var scaling = ScalingMode.fit
    private var metalLayer: CAMetalLayer? { surface.layer as? CAMetalLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(AppTheme.letterbox)
        clipsToBounds = true
        surface.backgroundColor = UIColor(AppTheme.letterbox)
        addSubview(surface)
        if let metalLayer { MetalRenderer.configureOutput(metalLayer) }
    }

    required init?(coder: NSCoder) { fatalError("Not used from a storyboard") }

    func place(content: CGSize?, scaling: ScalingMode) {
        guard content != self.content || scaling != self.scaling else { return }
        self.content = content
        self.scaling = scaling
        setNeedsLayout()
    }

    // A rotation between the two landscapes keeps the size, so it needs nothing here.
    override func layoutSubviews() {
        super.layoutSubviews()
        attach()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { detach() } else { attach() }
    }

    private func attach() {
        guard let window, let metalLayer else { return }
        let scale = window.screen.scale
        let canvas = CGSize(width: (bounds.width * scale).rounded(), height: (bounds.height * scale).rounded())
        guard canvas.width > 0, canvas.height > 0 else { return }
        // Before the first frame the core fits itself in the whole view.
        let frame = content.map { ScreenLayout.scaledRect(content: $0, canvas: canvas, mode: scaling) } ?? CGRect(origin: .zero, size: canvas)
        // Stretch: the layer keeps the frame's shape and a transform stretches it, so the drawable always matches
        // the layer's bounds and MoltenVK never sees a resized surface.
        let pixels = content.map { scaling == .stretch ? ScreenLayout.scaledRect(content: $0, canvas: frame.size, mode: .fit).size : frame.size }
            ?? frame.size
        surface.transform = .identity
        surface.bounds = CGRect(x: 0, y: 0, width: pixels.width / scale, height: pixels.height / scale)
        surface.center = CGPoint(x: frame.midX / scale, y: frame.midY / scale)
        surface.transform = CGAffineTransform(scaleX: frame.width / max(pixels.width, 1), y: frame.height / max(pixels.height, 1))
        surface.contentScaleFactor = scale
        guard pixels.width > 0, pixels.height > 0, pixels != attachedSize else { return }
        attachedSize = pixels
        session?.attachLayer(metalLayer, width: Int(pixels.width), height: Int(pixels.height), scale: scale)
    }

    func detach() {
        guard attachedSize != .zero, let metalLayer else { return }
        attachedSize = .zero
        session?.detachLayer(metalLayer)
    }
}

// MARK: - Touch controls

private struct TouchControls: View {
    @ObservedObject var session: GameSession
    @ObservedObject var skins: TouchSkinEngine

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                TouchInputLayer { session.setTouches($0, windowPoints: $1) }
                    .accessibilityHidden(true)
                ForEach(skins.skin?.buttons.filter { $0.shape != .hidden } ?? []) { button in
                    glyph(button)
                        .opacity(skins.opacity)
                        .frame(width: button.frame.width * geometry.size.width,
                               height: button.frame.height * geometry.size.height)
                        .scaleEffect(skins.scale)
                        .position(x: button.frame.midX * geometry.size.width,
                                  y: button.frame.midY * geometry.size.height)
                        // Touches go to the layer underneath, which tracks every finger.
                        .allowsHitTesting(false)
                        .accessibilityElement()
                        .accessibilityLabel(TouchSkinEngine.label(for: button.id).spoken)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { session.tapForAccessibility(button.mask) }
                }
            }
        }
    }

    @ViewBuilder private func glyph(_ button: TouchSkinEngine.Button) -> some View {
        let held = skins.pressed.contains(button.id)
        let content = held ? AppTheme.onAccent : AppTheme.onLetterbox
        let label = TouchSkinEngine.label(for: button.id).glyph
        switch button.shape {
        case .circle:
            Circle()
                .fill(held ? AppTheme.accentFill : Color.clear)
                .overlay(Circle().stroke(AppTheme.onLetterbox, lineWidth: 1))
                .overlay(Text(label ?? "").font(.system(.headline, design: .serif)).foregroundStyle(content))
        case .dpup, .dpdown, .dpleft, .dpright:
            pad(held).overlay(Image(systemName: Self.arrow(button.shape)).foregroundStyle(content))
        default:
            pad(held).overlay(
                Text(label ?? "").font(.meta).lineLimit(1).minimumScaleFactor(0.6).padding(.horizontal, 4)
                    .foregroundStyle(content)
            )
        }
    }

    private func pad(_ held: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.corner)
            .fill(held ? AppTheme.accentFill : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.onLetterbox, lineWidth: 1))
    }

    private static func arrow(_ shape: TouchSkinEngine.Button.Shape) -> String {
        switch shape {
        case .dpup: return "arrowtriangle.up.fill"
        case .dpdown: return "arrowtriangle.down.fill"
        case .dpleft: return "arrowtriangle.left.fill"
        default: return "arrowtriangle.right.fill"
        }
    }
}

/// Reports every active finger as a normalized point, and in window coordinates, on every change.
private struct TouchInputLayer: UIViewRepresentable {
    let onTouches: ([CGPoint], [CGPoint]) -> Void

    func makeUIView(context: Context) -> TouchInputView { TouchInputView() }

    func updateUIView(_ view: TouchInputView, context: Context) { view.onTouches = onTouches }
}

final class TouchInputView: UIView {
    var onTouches: (([CGPoint], [CGPoint]) -> Void)?
    private var active = Set<UITouch>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("Not used from a storyboard") }

    private func report() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let touches = Array(active)
        onTouches?(touches.map {
            let point = $0.location(in: self)
            return CGPoint(x: point.x / bounds.width, y: point.y / bounds.height)
        }, touches.map { $0.location(in: nil) })
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        active.formUnion(touches)
        report()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { report() }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        active.subtract(touches)
        report()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        active.subtract(touches)
        report()
    }
}

// MARK: - Pause menu

/// Compact side sheet. Entries for later milestones appear here only once they work.
private struct PauseMenu: View {
    @ObservedObject var session: GameSession
    @EnvironmentObject private var store: StoreKitManager
    @EnvironmentObject private var state: AppState
    @State private var showSaves = false
    @State private var showCheats = false
    @State private var showPlans = false
    @State private var showScreen = false
    @State private var saved: Date?

    private func resume() { session.resume(.menu) }

    /// Only an open paywall gate can reach this, and never for someone who owns the app outright.
    private var offersPlus: Bool { PaywallGate.isOpen && !store.entitlements.premium && store.entitlements.showsSubscribePrompts }

    var body: some View {
        HStack(spacing: 0) {
            // Lighter on the Screen page, so changes show on the picture.
            AppTheme.letterbox.opacity(showScreen ? 0.15 : 0.5)
                .contentShape(Rectangle())
                .onTapGesture(perform: resume)
                .accessibilityHidden(true)
            Rule()
            ScrollView {
                if showScreen { screenPage } else { mainPage }
            }
            .frame(width: 280)
            .foregroundStyle(AppTheme.ink)
            .background(AppTheme.paper)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) { if showScreen { showScreen = false } else { resume() } }
        }
        .ignoresSafeArea(edges: .vertical)
        .sheet(isPresented: $showSaves) {
            ManageSavesSheet(title: session.game.title, store: session.saves) { slot in
                try session.loadState(slot)
                session.resume(.menu)
            }
        }
        .sheet(isPresented: $showCheats) { CheatsSheet(session: session) }
        #if !GAGA_SIDELOAD
        .fullScreenCover(isPresented: $showPlans) { GagaPlusView() }
        #endif
    }

    /// Changes show on the picture beside the menu as they are made.
    private var screenPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showScreen = false } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent)
            Text("Screen").font(.screenTitle).accessibilityAddTraits(.isHeader)
            ScreenOptionsForm(settings: $session.screen, platformID: session.game.platformID, dual: session.isDualScreen,
                              gameOnly: gameOnly)
        }
        .padding(16)
    }

    /// On: this game keeps its own choice. Off: it drops it and uses its system's.
    private var gameOnly: Binding<Bool> {
        let id = session.game.id, platform = session.game.platformID
        return Binding(get: { state.screens.hasOverride(id) },
                       set: { on in
                           if on {
                               state.screens.save(session.screen, platformID: platform, gameID: id)
                           } else {
                               state.screens.removeOverride(id)
                               session.screen = state.screens.settings(platformID: platform, gameID: nil)
                           }
                       })
    }

    private var mainPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paused").font(.screenTitle).accessibilityAddTraits(.isHeader)
            Text(session.game.title).font(.meta).foregroundStyle(AppTheme.muted).lineLimit(3)
            Rule().padding(.vertical, 4)
            Button("Resume", action: resume).buttonStyle(PrimaryButtonStyle())
            if session.supportsSaveStates {
                menuRow(title: "Save State", value: saved.map { "Saved \($0.formatted(date: .omitted, time: .shortened))" }, action: saveState)
                menuRow(title: "Load State", action: { showSaves = true })
            }
            menuRow(title: "Screen", value: session.isDualScreen ? session.screen.preset.title : session.screen.scaling.title,
                    action: { showScreen = true })
            fastForward
            rewindNote
            if session.supportsCheats {
                menuRow(title: "Cheats", value: session.cheats.isEmpty ? nil : "\(session.cheats.count)", action: { showCheats = true })
            } else if let note = session.noCheatsNote {
                Text(note)
                    .font(.footnote).foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("noCheatsNote")
            }
            if offersPlus {
                menuRow(title: "See Gaga Plus", action: { showPlans = true })
            }
            Rule().padding(.vertical, 4)
            Button("Quit to Library", action: { session.stop() })
                .buttonStyle(QuietButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .padding(16)
    }

    private func saveState() {
        do {
            saved = try session.saveState().date
        } catch {
            session.notice = error.localizedDescription
        }
    }

    private func menuRow(title: String, value: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                if let value { Text(value).font(.meta).foregroundStyle(AppTheme.muted) }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Whether this core can rewind, and why not. Nothing while the setting is off.
    @ViewBuilder private var rewindNote: some View {
        let text: String? = switch session.rewindStatus {
        case .off: nil
        case .checking: "Rewind: checking this system."
        case .ready: "Rewind: hold the rewind button, or Options and L1 on a controller."
        case .unavailable(let reason): "Rewind is off. \(reason)"
        }
        if let text {
            Text(text)
                .font(.footnote).foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("rewindNote")
        }
    }

    private var fastForward: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fast Forward").accessibilityAddTraits(.isHeader)
            HStack(spacing: 6) {
                ForEach(session.fastForwardSpeeds, id: \.self) { speed in
                    let selected = session.fastForward == speed
                    let label = speed == 1 ? "Off" : "\(speed)x"
                    Button { session.setFastForward(speed) } label: {
                        Text(label)
                            .font(.footnote.weight(selected ? .bold : .regular))
                            .foregroundStyle(selected ? AppTheme.onAccent : AppTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selected ? AppTheme.accentFill : Color.clear, in: RoundedRectangle(cornerRadius: AppTheme.corner))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(selected ? Color.clear : AppTheme.rule, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(speed == 1 ? "Normal speed" : "\(speed) times speed")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}
