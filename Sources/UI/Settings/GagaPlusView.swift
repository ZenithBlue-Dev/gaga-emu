import StoreKit
import SwiftUI

/// Paywall: benefits left, plans right. Offer badges and disclosure follow the product.
struct GagaPlusView: View {
    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var selected: StoreKitManager.ProductID = .annual
    @State private var buying = false
    @State private var showRedeem = false

    /// Names the cores in this build that draw their own picture, where no filter runs (docs/05 section 2.3).
    static func filterStatement(layerPathCores: [String]) -> String {
        let base = "Premium Filters work only on cores that draw through the app's filter chain."
        guard !layerPathCores.isEmpty else { return base }
        let verb = layerPathCores.count == 1 ? "draws its" : "draw their"
        return base + " \(layerPathCores.formatted(.list(type: .and))) \(verb) own 3D picture, so filters do not apply there."
    }

    private let benefits: [(String, String)] = [
        ("Faster fast-forward", "Up to 5x instead of 2x."),
        ("More save states", "No limit instead of 3."),
        ("More cheat codes", "No limit instead of 3."),
        ("Premium Filters", "Adds Geom CRT, Geom CRT Border, CRT Deluxe and Anime4K."),
        ("Auto save state", "Saves your place for you.")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gaga Plus").font(.screenTitle).accessibilityAddTraits(.isHeader)
                    Text("Every core and platform stays free. Plus adds:").foregroundStyle(AppTheme.muted)
                    Rule()
                    ForEach(benefits, id: \.0) { title, detail in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).fontWeight(.medium)
                            Text(detail).font(.footnote).foregroundStyle(AppTheme.muted)
                        }
                        .accessibilityElement(children: .combine)
                        Rule()
                    }
                    Text(Self.filterStatement(layerPathCores: CoreCatalog.layerPathCoreNames))
                        .font(.footnote).foregroundStyle(AppTheme.muted)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            Rule().ignoresSafeArea(edges: .vertical)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer(minLength: 0)
                        Button("Close") { dismiss() }.buttonStyle(QuietButtonStyle())
                    }
                    if store.entitlements.showsSubscribePrompts {
                        plans
                    } else {
                        Text("Your Lifetime plan is active.").font(.gameTitle)
                    }
                    HStack(spacing: 16) {
                        Button("Redeem Offer") { showRedeem = true }
                        Button("Restore Purchases") { Task { await store.restore() } }
                    }
                    .font(.footnote)
                    .buttonStyle(QuietButtonStyle())
                    HStack(spacing: 16) {
                        Link("Terms of Service", destination: URL(string: SiteLinks.terms)!)
                        Link("Privacy Policy", destination: URL(string: SiteLinks.privacy)!)
                    }
                    .font(.footnote)
                    .buttonStyle(QuietButtonStyle())
                    if let error = store.lastError {
                        Text(error).font(.footnote).foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper.ignoresSafeArea())
        .task { await store.refresh() }
        .offerCodeRedemption(isPresented: $showRedeem) { _ in
            Task { await store.refresh() }
        }
    }

    @ViewBuilder private var plans: some View {
        ForEach(offers) { offer in planRow(offer) }
        if let disclosure = offers.first(where: { $0.productID == selected })?.disclosure {
            Text(disclosure).font(.footnote).foregroundStyle(AppTheme.muted)
        }
        Button(buying ? "Working…" : selected == .lifetime ? "Buy Lifetime" : "Subscribe") { buy() }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(buying || store.offers.isEmpty && !store.isLoading)
    }

    private var offers: [StoreKitManager.Offer] { store.offers.isEmpty ? Self.placeholders : store.offers }

    private func planRow(_ offer: StoreKitManager.Offer) -> some View {
        let isSelected = selected == offer.productID
        return Button { selected = offer.productID } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.muted)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.productID.title).fontWeight(isSelected ? .bold : .regular)
                    if let badge = offer.badge { Text(badge).font(.meta).foregroundStyle(AppTheme.muted) }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(offer.displayPrice)\(offer.periodSuffix)").font(.system(.body, design: .monospaced))
                    if let subtitle = offer.subtitle { Text(subtitle).font(.meta).foregroundStyle(AppTheme.muted) }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .overlay(RoundedRectangle(cornerRadius: AppTheme.corner)
                .stroke(isSelected ? AppTheme.accent : AppTheme.rule, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func buy() {
        buying = true
        Task {
            let ok = await store.purchase(selected)
            buying = false
            if ok { dismiss() }
        }
    }

    /// Shown before StoreKit answers so the layout never flashes empty.
    static let placeholders: [StoreKitManager.Offer] = [
        .init(productID: .monthly, displayPrice: "—", price: 0, periodSuffix: "/month", intro: nil, subtitle: nil),
        .init(productID: .annual, displayPrice: "—", price: 0, periodSuffix: "/year", intro: nil, subtitle: nil),
        .init(productID: .lifetime, displayPrice: "—", price: 0, periodSuffix: "", intro: nil, subtitle: nil)
    ]
}
