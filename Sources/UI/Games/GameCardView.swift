import SwiftUI

/// Cover tile. Shows a gradient stand-in when no boxart has been scraped.
struct GameCardView: View {
    let game: GameItem
    var width: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                cover
                    .frame(width: width, height: width * 1.35)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(platformBadge)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(8)
            }
            Text(game.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(playtime)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var cover: some View {
        Group {
            if let path = game.coverPath, let image = uiImage(path) {
                image.resizable().scaledToFill()
            } else {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Text(initials).font(.system(size: 36, weight: .black)).foregroundStyle(.white.opacity(0.85)))
            }
        }
    }

    private var initials: String {
        let words = game.title.split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private var playtime: String {
        let minutes = Int(game.playTime) / 60
        return minutes > 0 ? "\(minutes)m played" : "Not played"
    }

    private var platformBadge: String {
        CoreCatalog.platform(game.platformID)?.name ?? game.platformID.uppercased()
    }

    private var gradient: [Color] {
        switch game.platformID {
        case "gba", "gbc", "gb": return [.purple, .indigo]
        case "snes", "nes": return [.red, .orange]
        case "ps1", "psp": return [.blue, .cyan]
        case "n64", "nds", "n3ds": return [.green, .teal]
        default: return [.pink, .orange]
        }
    }

    private func uiImage(_ path: String) -> Image? {
        #if canImport(UIKit)
        guard let ui = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: ui)
        #else
        return nil
        #endif
    }
}
