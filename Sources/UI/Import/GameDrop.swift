import SwiftUI
import UniformTypeIdentifiers

/// The file types Files import offers and drops accept.
enum GameFileTypes {
    static let all: [UTType] = {
        var types: [UTType] = [.zip, .data, .item]
        for ext in ["gba", "gbc", "gb", "nes", "sfc", "smc", "n64", "z64", "nds", "3ds", "iso", "chd", "cue", "ccd", "toc", "bin", "pbp", "cso", "gdi", "cdi", "7z", "rar", "m3u", "exe", "com", "bat", "dosz", "ins", "ima", "vhd", "jrc", "m3u8", "conf", "pce", "sgx", "vb", "vboy", "ngp", "ngc", "ngpc", "npc", "ws", "wsc", "pc2", "min", "sms", "gg", "sg", "mv", "a26", "a78", "lnx", "a52", "xex", "atr", "xfd", "dcm", "atx", "j64", "jag", "d64", "t64", "prg", "crt", "tap", "adf", "hdf", "wad", "3dsx", "cci", "cxi"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }()
}

extension View {
    /// Imports game files dropped anywhere on this view (`AppState.importDropped`). `notice` gets each file's
    /// result line, and whether it is a problem.
    func gameFileDrop(isTargeted: Binding<Bool>, notice: @escaping @MainActor (String, Bool) -> Void) -> some View {
        modifier(GameFileDrop(isTargeted: isTargeted, notice: notice))
    }

    /// Asks which system a disc image or archive is for when its contents did not say (`AppState.unplaced`).
    func unplacedQuestion() -> some View { modifier(UnplacedQuestion()) }

    /// A dashed accent frame while a drop hovers, so the screen shows it will take the files.
    func dropHighlight(_ on: Bool) -> some View {
        overlay {
            if on {
                RoundedRectangle(cornerRadius: AppTheme.corner)
                    .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .padding(4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct GameFileDrop: ViewModifier {
    @EnvironmentObject private var state: AppState
    @Binding var isTargeted: Bool
    let notice: @MainActor (String, Bool) -> Void

    func body(content: Content) -> some View {
        content.onDrop(of: GameFileTypes.all, isTargeted: $isTargeted) { state.importDropped($0, done: notice) }
    }
}

private struct UnplacedQuestion: ViewModifier {
    @EnvironmentObject private var state: AppState

    func body(content: Content) -> some View {
        content.confirmationDialog("Which system is \(state.unplaced.first?.title ?? "this disc") for?",
                                   isPresented: Binding(get: { !state.unplaced.isEmpty },
                                                        set: { if !$0, !state.unplaced.isEmpty { state.unplaced.removeFirst() } }),
                                   titleVisibility: .visible) {
            ForEach(state.unplaced.first.flatMap { CoreCatalog.unplacedPlatforms(forFile: URL(fileURLWithPath: $0.romPath)) } ?? []) { platform in
                Button(platform.name) {
                    if let game = state.unplaced.first { state.update(game.id) { $0.platformID = platform.id } }
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("GagaEmu could not tell from the file.")
        }
    }
}
