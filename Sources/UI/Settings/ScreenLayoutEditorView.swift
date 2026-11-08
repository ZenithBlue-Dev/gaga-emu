import SwiftUI

extension ScreenLayout {
    /// The custom place a screen fills: the top place shows the top screen unless swapped.
    static func customRect(_ settings: ScreenSettings, for id: ScreenID) -> CGRect? {
        (id == .top) != settings.swapped ? settings.customTop : settings.customBottom
    }

    static func setCustomRect(_ settings: inout ScreenSettings, for id: ScreenID, _ rect: CGRect) {
        if (id == .top) != settings.swapped { settings.customTop = rect } else { settings.customBottom = rect }
    }

    /// `rect` moved by `offset`, kept on the canvas when it fits there.
    static func moved(_ rect: CGRect, by offset: CGSize) -> CGRect {
        var r = rect.offsetBy(dx: offset.width, dy: offset.height)
        if r.width <= 1 { r.origin.x = min(max(r.minX, 0), 1 - r.width) }
        if r.height <= 1 { r.origin.y = min(max(r.minY, 0), 1 - r.height) }
        return r
    }

    /// `rect` scaled about its centre by `sx` and `sy`, moved back onto the canvas. Refused, unchanged, when it
    /// would be larger than the canvas.
    static func resized(_ rect: CGRect, sx: CGFloat, sy: CGFloat) -> CGRect {
        let width = rect.width * sx, height = rect.height * sy
        guard width <= 1, height <= 1, width > 0, height > 0 else { return rect }
        return moved(CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height), by: .zero)
    }
}

/// Pause menu or Settings > Screen > Edit Custom Layout: drag each screen to move it, pinch or use Smaller and
/// Larger to size it, show or hide it, then save. The canvas is the whole game view, as a custom layout uses
/// it. Save stays off while `ScreenLayout.problems` finds anything.
struct ScreenLayoutEditorView: View {
    @Binding var settings: ScreenSettings
    let platformID: String
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ScreenSettings()
    @State private var selected = ScreenID.bottom
    @State private var keepShape = true
    @State private var gestureStart: CGRect?
    @State private var panelAtTop = true
    @State private var loaded = false

    var body: some View {
        // The canvas is the whole display; the panel keeps clear of the notch and home indicator, read outside it.
        GeometryReader { outer in
            let insets = outer.safeAreaInsets
            GeometryReader { geometry in
                let canvas = geometry.size
                ZStack(alignment: panelAtTop ? .top : .bottom) {
                    Color.clear
                    ForEach([ScreenID.top, .bottom], id: \.self) { id in
                        if shows(id), let rect = ScreenLayout.customRect(draft, for: id) { box(id, rect: rect, canvas: canvas) }
                    }
                    panel(canvas)
                        .padding(EdgeInsets(top: panelAtTop ? insets.top : 0, leading: insets.leading,
                                            bottom: panelAtTop ? 0 : insets.bottom, trailing: insets.trailing))
                }
                .onAppear { if !loaded { load(canvas) } }
            }
            .ignoresSafeArea()
        }
        .background(AppTheme.letterbox.ignoresSafeArea())
        .statusBarHidden(true)
    }

    private func shows(_ id: ScreenID) -> Bool { id == .top ? draft.showTop : draft.showBottom }

    private func name(_ id: ScreenID) -> String { id == .top ? "Top screen" : "Bottom screen" }

    private func load(_ canvas: CGSize) {
        loaded = true
        draft = settings
        draft.preset = .custom
        if draft.customTop == nil || draft.customBottom == nil { reset(canvas) }
    }

    /// The places of the layout chosen before Custom, or Stacked.
    private func reset(_ canvas: CGSize) {
        let places = ScreenLayout.customRects(platformID: platformID, canvas: canvas, from: settings)
        if let top = places.top { ScreenLayout.setCustomRect(&draft, for: .top, top) }
        if let bottom = places.bottom { ScreenLayout.setCustomRect(&draft, for: .bottom, bottom) }
    }

    /// The screen's width over its height, turned if asked.
    private func aspect(_ id: ScreenID) -> CGFloat {
        guard let frame = ScreenLayout.nominalFrame(platformID),
              let region = ScreenLayout.regions(platformID: platformID, frame: frame)?.first(where: { $0.id == id }) else { return 4 / 3 }
        let ratio = region.pixels.width / region.pixels.height
        return draft.rotation == .none ? ratio : 1 / ratio
    }

    private func update(_ id: ScreenID, _ change: (CGRect) -> CGRect) {
        guard let rect = ScreenLayout.customRect(draft, for: id) else { return }
        ScreenLayout.setCustomRect(&draft, for: id, change(rect))
    }

    /// Larger or smaller keeps the shape. With Keep Shape off, `sx` and `sy` may differ.
    private func resize(_ id: ScreenID, sx: CGFloat, sy: CGFloat) {
        update(id) { ScreenLayout.resized($0, sx: sx, sy: sy) }
    }

    /// Turning Keep Shape back on restores the screen's own shape, keeping its width.
    private func restoreShape(_ canvas: CGSize) {
        for id in [ScreenID.top, .bottom] {
            update(id) { rect in
                let height = rect.width * canvas.width / aspect(id) / canvas.height
                return ScreenLayout.moved(CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: min(height, 1)), by: .zero)
            }
        }
    }

    // MARK: Screens

    private func box(_ id: ScreenID, rect: CGRect, canvas: CGSize) -> some View {
        accessible(gestures(face(id), id: id, rect: rect, canvas: canvas), id: id)
    }

    private func face(_ id: ScreenID) -> some View {
        let isSelected = selected == id
        let fill: Color = isSelected ? AppTheme.accentFill.opacity(0.35) : AppTheme.onLetterbox.opacity(0.12)
        let outline = RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.onLetterbox, lineWidth: isSelected ? 2 : 1)
        let label = Text(id == .top ? "Top" : "Bottom").font(.headline).foregroundStyle(AppTheme.onLetterbox)
        return RoundedRectangle(cornerRadius: AppTheme.corner).fill(fill).overlay(outline).overlay(label)
    }

    private func gestures(_ face: some View, id: ScreenID, rect: CGRect, canvas: CGSize) -> some View {
        face
            .frame(width: rect.width * canvas.width, height: rect.height * canvas.height)
            .contentShape(Rectangle())
            .position(x: rect.midX * canvas.width, y: rect.midY * canvas.height)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if gestureStart == nil { gestureStart = rect; selected = id }
                    guard let start = gestureStart else { return }
                    update(id) { _ in ScreenLayout.moved(start, by: CGSize(width: value.translation.width / canvas.width,
                                                                            height: value.translation.height / canvas.height)) }
                }
                .onEnded { _ in gestureStart = nil })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { value in
                    if gestureStart == nil { gestureStart = rect; selected = id }
                    guard let start = gestureStart else { return }
                    update(id) { _ in ScreenLayout.resized(start, sx: value.magnification, sy: value.magnification) }
                }
                .onEnded { _ in gestureStart = nil })
    }

    private func accessible(_ view: some View, id: ScreenID) -> some View {
        view
            .accessibilityElement()
            .accessibilityLabel(name(id))
            .accessibilityValue(selected == id ? "Selected" : "")
            .accessibilityHint("Drag to move, pinch to size. Actions move and size it.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { selected = id }
            .accessibilityAction(named: "Move Left") { update(id) { ScreenLayout.moved($0, by: CGSize(width: -0.02, height: 0)) } }
            .accessibilityAction(named: "Move Right") { update(id) { ScreenLayout.moved($0, by: CGSize(width: 0.02, height: 0)) } }
            .accessibilityAction(named: "Move Up") { update(id) { ScreenLayout.moved($0, by: CGSize(width: 0, height: -0.04)) } }
            .accessibilityAction(named: "Move Down") { update(id) { ScreenLayout.moved($0, by: CGSize(width: 0, height: 0.04)) } }
            .accessibilityAction(named: "Larger") { resize(id, sx: 1.1, sy: 1.1) }
            .accessibilityAction(named: "Smaller") { resize(id, sx: 0.9, sy: 0.9) }
    }

    // MARK: Panel

    private func panel(_ canvas: CGSize) -> some View {
        let problems = ScreenLayout.problems(draft, canvas: canvas)
        return VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach([ScreenID.top, .bottom], id: \.self) { id in
                        Button(id == .top ? "Top" : "Bottom") { selected = id }
                            .buttonStyle(QuietButtonStyle())
                            .fontWeight(selected == id ? .bold : .regular)
                            .accessibilityLabel(name(id))
                            .accessibilityAddTraits(selected == id ? .isSelected : [])
                    }
                    Rule().frame(width: 1, height: 28)
                    Button("Smaller") { resize(selected, sx: 0.9, sy: 0.9) }.buttonStyle(QuietButtonStyle())
                    Button("Larger") { resize(selected, sx: 1.1, sy: 1.1) }.buttonStyle(QuietButtonStyle())
                    if !keepShape {
                        Button("Narrower") { resize(selected, sx: 0.9, sy: 1) }.buttonStyle(QuietButtonStyle())
                        Button("Wider") { resize(selected, sx: 1.1, sy: 1) }.buttonStyle(QuietButtonStyle())
                        Button("Shorter") { resize(selected, sx: 1, sy: 0.9) }.buttonStyle(QuietButtonStyle())
                        Button("Taller") { resize(selected, sx: 1, sy: 1.1) }.buttonStyle(QuietButtonStyle())
                    }
                    Toggle("Keep Shape", isOn: Binding(get: { keepShape }, set: { keepShape = $0; if $0 { restoreShape(canvas) } }))
                        .tint(AppTheme.accentFill)
                        .fixedSize()
                    Button(shows(selected) ? "Hide" : "Show") {
                        if selected == .top { draft.showTop.toggle() } else { draft.showBottom.toggle() }
                    }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityLabel("\(shows(selected) ? "Hide" : "Show") \(name(selected).lowercased())")
                    Rule().frame(width: 1, height: 28)
                    Button("Reset to Preset") { reset(canvas) }.buttonStyle(QuietButtonStyle())
                    Button(panelAtTop ? "Panel Down" : "Panel Up") { panelAtTop.toggle() }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityLabel("Move this panel to the \(panelAtTop ? "bottom" : "top")")
                }
                .frame(minHeight: 44)
            }
            // Outside the scrolling row, so Save is always in reach on a narrow screen.
            HStack(spacing: 8) {
                Text(problems.first ?? (draft.showBottom ? "Ready to save." : "Ready to save. With the bottom screen hidden, touch input is off."))
                    .font(.footnote)
                    .foregroundStyle(problems.isEmpty ? AppTheme.muted : AppTheme.accent)
                    .accessibilityAddTraits(.updatesFrequently)
                Spacer(minLength: 0)
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle())
                Button("Save") {
                    settings = draft
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .fixedSize()
                .disabled(!problems.isEmpty)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: AppTheme.corner))
        .padding(8)
    }
}
