import SwiftUI

/// Cover with its platform spine. A generated typographic placeholder stands in without boxart.
struct CoverArt: View {
    @EnvironmentObject private var state: AppState
    let game: GameItem
    let width: CGFloat

    private var height: CGFloat { width * 4 / 3 }

    var body: some View {
        ZStack(alignment: .leading) {
            if let path = state.coverURL(for: game)?.path, let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: width, height: height).clipped()
            } else {
                placeholder
            }
            Rectangle().fill(AppTheme.spine(game.platformID)).frame(width: 3)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.corner).stroke(AppTheme.rule, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(game.title.prefix(1).uppercased())
                .font(.system(size: width * 0.42, weight: .regular, design: .serif))
            Spacer(minLength: 0)
            Text(CoreCatalog.platformCode(game.platformID))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.leading, 11).padding(.trailing, 6).padding(.vertical, 8)
        .frame(width: width, height: height, alignment: .leading)
        .background(AppTheme.surface)
    }
}
