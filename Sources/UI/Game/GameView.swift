import MetalKit
import SwiftUI

/// Picture centred on ink, touch controls in the bands left and right of it, pause menu on top.
struct GameView: View {
    @ObservedObject var session: GameSession
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var controllers: ControllerManager
    @EnvironmentObject private var skins: TouchSkinEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var touchVisible: Bool { controllers.touchOwnsPlayerOne }

    var body: some View {
        GeometryReader { geometry in
            let reserveBands = touchVisible || !state.autoFullScreen
            ZStack(alignment: .topLeading) {
                GamePicture(session: session)
                    .padding(.horizontal, reserveBands ? geometry.size.width * TouchSkinEngine.controlBand : 0)
                    .ignoresSafeArea(edges: .vertical)
                    .accessibilityElement()
                    .accessibilityLabel("\(session.game.title), game picture")
                    .accessibilityAddTraits(.isImage)
                if touchVisible { TouchControls(session: session, skins: skins) }
                HStack(spacing: 0) {
                    pauseButton
                    Spacer(minLength: 0)
                    fastForwardButton
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: session.menuOpen)
        .background(AppTheme.letterbox.ignoresSafeArea())
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onChange(of: touchVisible) { session.clearTouches() }
        .onAppear { session.run() }
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

private struct GamePicture: UIViewRepresentable {
    @ObservedObject var session: GameSession

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: session.renderer.device)
        view.delegate = session.renderer
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MetalRenderer.letterboxColor
        view.preferredFramesPerSecond = Int(session.targetFPS.rounded(.up))
        return view
    }

    /// No draws while paused, which also keeps GPU work out of the background.
    func updateUIView(_ view: MTKView, context: Context) {
        view.isPaused = session.phase != .running && session.phase != .prepared
    }
}

// MARK: - Touch controls

private struct TouchControls: View {
    @ObservedObject var session: GameSession
    @ObservedObject var skins: TouchSkinEngine

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                TouchInputLayer { session.setTouches($0) }
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

/// Reports every active finger as a normalized point, on every change.
private struct TouchInputLayer: UIViewRepresentable {
    let onTouches: ([CGPoint]) -> Void

    func makeUIView(context: Context) -> TouchInputView { TouchInputView() }

    func updateUIView(_ view: TouchInputView, context: Context) { view.onTouches = onTouches }
}

final class TouchInputView: UIView {
    var onTouches: (([CGPoint]) -> Void)?
    private var active = Set<UITouch>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("Not used from a storyboard") }

    private func report() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        onTouches?(active.map {
            let point = $0.location(in: self)
            return CGPoint(x: point.x / bounds.width, y: point.y / bounds.height)
        })
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
    @State private var showSaves = false
    @State private var showCheats = false
    @State private var showPlans = false
    @State private var saved: Date?

    private func resume() { session.resume(.menu) }

    /// Only an open paywall gate can reach this, and never for someone who owns the app outright.
    private var offersPlus: Bool { PaywallGate.isOpen && !store.entitlements.premium && store.entitlements.showsSubscribePrompts }

    var body: some View {
        HStack(spacing: 0) {
            AppTheme.letterbox.opacity(0.5)
                .contentShape(Rectangle())
                .onTapGesture(perform: resume)
                .accessibilityHidden(true)
            Rule()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paused").font(.screenTitle).accessibilityAddTraits(.isHeader)
                    Text(session.game.title).font(.meta).foregroundStyle(AppTheme.muted).lineLimit(3)
                    Rule().padding(.vertical, 4)
                    Button("Resume", action: resume).buttonStyle(PrimaryButtonStyle())
                    if session.supportsSaveStates {
                        menuRow(title: "Save State", value: saved.map { "Saved \($0.formatted(date: .omitted, time: .shortened))" }, action: saveState)
                        menuRow(title: "Load State", action: { showSaves = true })
                    }
                    fastForward
                    if session.supportsCheats {
                        menuRow(title: "Cheats", value: session.cheats.isEmpty ? nil : "\(session.cheats.count)", action: { showCheats = true })
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
            .frame(width: 280)
            .foregroundStyle(AppTheme.ink)
            .background(AppTheme.paper)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, resume)
        }
        .ignoresSafeArea(edges: .vertical)
        .sheet(isPresented: $showSaves) {
            ManageSavesSheet(title: session.game.title, store: session.saves) { slot in
                try session.loadState(slot)
                session.resume(.menu)
            }
        }
        .sheet(isPresented: $showCheats) { CheatsSheet(session: session) }
        .fullScreenCover(isPresented: $showPlans) { GagaPlusView() }
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
