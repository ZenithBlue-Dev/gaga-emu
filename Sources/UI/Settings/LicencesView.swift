import SwiftUI

/// One shipped component and its licence texts, from `licences.json`, which
/// `scripts/generate-licences.py` writes from the committed list `Licences/notices.json`.
struct LicenceNotice: Decodable, Identifiable, Equatable {
    struct Text: Decodable, Equatable {
        let title: String
        /// A `licence-*.txt` resource in the app bundle.
        let file: String
    }

    let id: String
    let title: String
    let licence: String
    let source: String
    /// Empty for a part every build carries. Otherwise the cores that bring it in.
    let cores: [String]
    /// The core framework this component covers, if it is one.
    let framework: String?
    let texts: [Text]

    /// Shown only when this build links it (`GAGA_CORE_SET`).
    var isLinked: Bool { cores.isEmpty || cores.contains { !GagaCoreRegistry_IsExcluded($0) } }

    static func all(bundle: Bundle = .main) -> [LicenceNotice] {
        struct File: Decodable { let components: [LicenceNotice] }
        guard let url = bundle.url(forResource: "licences", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode(File.self, from: data).components) ?? []
    }

    static func linked(bundle: Bundle = .main) -> [LicenceNotice] { all(bundle: bundle).filter(\.isLinked) }

    static func text(_ file: String, bundle: Bundle = .main) -> String? {
        let name = (file as NSString).deletingPathExtension
        return bundle.url(forResource: name, withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
}

/// Settings > About > Licences: components on the left, the chosen one's texts on the right.
struct LicencesView: View {
    @Environment(\.verticalSizeClass) private var verticalSize
    @ScaledMetric(relativeTo: .body) private var columnScale: CGFloat = 1
    private let notices = LicenceNotice.linked()
    @State private var selected: LicenceNotice.ID?

    var body: some View {
        PaperSheet(title: "Licences", subtitle: "Parts this build includes", scrolls: false) {
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(notices) { row($0) }
                    }
                }
                .frame(width: (verticalSize == .compact ? 190 : 260) * min(columnScale, 1.5))
                Rule()
                ScrollView {
                    if let notice = notices.first(where: { $0.id == (selected ?? notices.first?.id) }) {
                        detail(notice)
                    }
                }
                .id(selected)
            }
        }
    }

    private func row(_ notice: LicenceNotice) -> some View {
        let isSelected = notice.id == (selected ?? notices.first?.id)
        return Button { selected = notice.id } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title).fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.ink)
                Text(notice.licence).font(.meta).foregroundStyle(AppTheme.muted)
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                if isSelected { Rectangle().fill(AppTheme.accent).frame(width: 3) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func detail(_ notice: LicenceNotice) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(notice.title).font(.gameTitle).accessibilityAddTraits(.isHeader)
            Text(notice.source).font(.footnote).foregroundStyle(AppTheme.muted)
            // Titles are unique in a component; files are not, since one text can serve several parts.
            ForEach(notice.texts, id: \.title) { item in
                Rule().padding(.vertical, 4)
                Text(item.title).font(.headline).accessibilityAddTraits(.isHeader)
                Text(LicenceNotice.text(item.file) ?? "")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
