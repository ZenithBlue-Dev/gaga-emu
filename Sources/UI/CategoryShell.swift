import SwiftUI

/// A category Settings or Style lists: its name, its symbol, and its accessibility identifier.
protocol ShellCategory: Hashable, Identifiable {
    var title: String { get }
    var symbol: String { get }
    var identifier: String { get }
}

/// Categories with an icon each, and the chosen one's page. Upright on a phone the categories are a sideways strip of
/// icon and one-word label under the title; otherwise a sidebar list with icons. `accessory` sits above them (search).
struct CategoryShell<Item: ShellCategory, Accessory: View, Detail: View>: View {
    let title: String
    let items: [Item]
    @Binding var selection: Item
    let detailTitle: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var detail: Detail
    @Environment(\.verticalSizeClass) private var verticalSize
    @Environment(\.horizontalSizeClass) private var horizontalSize
    /// The category column widens with Dynamic Type so names do not break mid-word.
    @ScaledMetric(relativeTo: .body) private var columnScale: CGFloat = 1

    var body: some View {
        let upright = horizontalSize == .compact && verticalSize == .regular
        AnyLayout(upright ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))) {
            if upright {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title)).font(.screenTitle).accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 16).padding(.top, 8)
                    accessory.padding(.horizontal, 16)
                    ScrollViewReader { reader in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 2) {
                                ForEach(items) { chip($0).id($0.id) }
                            }
                            .padding(.horizontal, 8)
                        }
                        .onAppear { reader.scrollTo(selection.id) }
                        .onChange(of: selection) { reader.scrollTo(selection.id, anchor: .center) }
                    }
                }
                Rule()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(LocalizedStringKey(title)).font(.screenTitle).accessibilityAddTraits(.isHeader)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                        accessory.padding(.horizontal, 12).padding(.bottom, 8)
                        ForEach(items) { sideRow($0) }
                    }
                }
                .frame(width: (verticalSize == .compact ? 200 : 260) * min(columnScale, 1.5))
                Rule(vertical: true).ignoresSafeArea(edges: .vertical)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(LocalizedStringKey(detailTitle)).font(.gameTitle).accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 8)
                    detail
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(detailTitle)
        }
    }

    /// Icon over a one-word label, underlined when chosen.
    private func chip(_ item: Item) -> some View {
        let selected = selection == item
        return Button { selection = item } label: {
            VStack(spacing: 2) {
                Image(systemName: item.symbol).font(.body.weight(selected ? .semibold : .regular)).accessibilityHidden(true)
                Text(LocalizedStringKey(item.title)).font(.caption.weight(selected ? .bold : .regular)).lineLimit(1)
            }
            .foregroundStyle(selected ? AppTheme.accent : AppTheme.ink)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .frame(minWidth: 64, minHeight: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if selected { Rectangle().fill(AppTheme.accent).frame(height: 3) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(item.identifier)
        // The strip keeps one height; the large content viewer shows the label at larger sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
    }

    /// Icon tile then name, with a bar at the leading edge when chosen.
    private func sideRow(_ item: Item) -> some View {
        let selected = selection == item
        return Button { selection = item } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.corner))
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(item.title))
                    .fontWeight(selected ? .bold : .regular)
                    .foregroundStyle(selected ? AppTheme.accent : AppTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                if selected { Rectangle().fill(AppTheme.accent).frame(width: 3) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(item.identifier)
    }
}
