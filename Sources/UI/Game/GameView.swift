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
                pauseButton
            }
        }
        .overlay {
            if session.menuOpen {
                PauseMenu(title: session.game.title,
                          resume: { session.resume(.menu) },
                          quit: { session.stop() })
                    .transition(.opacity)
            }
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
    let title: String
    let resume: () -> Void
    let quit: () -> Void

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
                    Text(title).font(.meta).foregroundStyle(AppTheme.muted).lineLimit(3)
                    Rule().padding(.vertical, 4)
                    Button("Resume", action: resume).buttonStyle(PrimaryButtonStyle())
                    Button("Quit to Library", action: quit)
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
    }
}
