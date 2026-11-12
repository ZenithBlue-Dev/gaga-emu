// The paywall. A sideload build (GAGA_SIDELOAD) has none: its non-commercial cores forbid selling it.
#if !GAGA_SIDELOAD
import StoreKit
import SwiftUI

/// GagaEmu Pro: what Pro adds on the left, the three plans on the right; upright on a phone, one scroll.
/// Prices and periods are StoreKit's. The benefits match `StoreKitManager.Entitlements`, the limits the app enforces.
struct GagaPlusView: View {
    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSize
    @Environment(\.verticalSizeClass) private var verticalSize
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selected: StoreKitManager.ProductID = .yearly
    @State private var buying = false
    @State private var showRedeem = false
    @State private var showManage = false

    /// Names the cores in this build that draw their own picture, where no filter runs (docs/05 section 2.3).
    static func filterStatement(layerPathCores: [String]) -> String {
        let base = "Premium Filters work only on cores that draw through the app's filter chain."
        guard !layerPathCores.isEmpty else { return base }
        let verb = layerPathCores.count == 1 ? "draws its" : "draw their"
        return base + " \(layerPathCores.formatted(.list(type: .and))) \(verb) own 3D picture, so filters do not apply there."
    }

    static let disclosure = "Monthly and Yearly renew automatically unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple Account when you confirm. Any unused free trial ends when you subscribe. Manage or cancel in Settings > Apple Account > Subscriptions. Forever is one payment."

    private let benefits: [(String, String)] = [
        ("Fast forward above 2x", "Up to 5x."),
        ("More save slots and cheats", "Free keeps 4 save slots and 5 cheats per game."),
        ("Players 3 and 4", "Four controllers on systems that have them."),
        ("The full shader catalogue", "Free keeps Original, Sharp Bilinear, Lottes CRT and LCD3x."),
        ("iCloud sync", "Saves and states on all your devices."),
        ("Extra app icons and themes", "More looks for GagaEmu.")
    ]

    var body: some View {
        let upright = horizontalSize == .compact && verticalSize == .regular
        Group {
            if upright {
                VStack(spacing: 0) {
                    closeBar.padding(.horizontal, 16)
                    ScrollView {
                        VStack(spacing: 0) {
                            benefitsColumn
                            planColumn
                        }
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ScrollView { benefitsColumn }.frame(maxWidth: .infinity)
                    Rule().ignoresSafeArea(edges: .vertical)
                    VStack(spacing: 0) {
                        closeBar.padding(.horizontal, 16)
                        ScrollView { planColumn }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .foregroundStyle(AppTheme.ink)
        .background(AppTheme.paper.ignoresSafeArea())
        .task { await store.refresh() }
        .offerCodeRedemption(isPresented: $showRedeem) { _ in
            Task { await store.refresh() }
        }
        .manageSubscriptionsSheet(isPresented: $showManage)
    }

    private var closeBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button("Close") { dismiss() }.buttonStyle(QuietButtonStyle())
        }
    }

    private var benefitsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GagaEmu Pro").font(.screenTitle).accessibilityAddTraits(.isHeader)
            Text("Every system and core stays free to play. No ads, no sign-in.").foregroundStyle(AppTheme.muted)
            Rule()
            ForEach(benefits, id: \.0) { title, detail in
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title)).fontWeight(.medium)
                    Text(LocalizedStringKey(detail)).font(.footnote).foregroundStyle(AppTheme.muted)
                }
                .accessibilityElement(children: .combine)
                Rule()
            }
            Text(Self.filterStatement(layerPathCores: CoreCatalog.layerPathCoreNames))
                .font(.footnote).foregroundStyle(AppTheme.muted)
        }
        .padding(16)
    }

    private var planColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.isPro {
                Text("You have GagaEmu Pro").font(.gameTitle).accessibilityAddTraits(.isHeader)
                if store.purchased.lifetime {
                    Text("Forever: nothing more to pay.").font(.footnote).foregroundStyle(AppTheme.muted)
                }
            } else {
                plans
            }
            Text(LocalizedStringKey(Self.disclosure)).font(.footnote).foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if let error = store.lastError {
                Text(error).font(.footnote).foregroundStyle(AppTheme.accent)
            }
            links
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
    }

    @ViewBuilder private var plans: some View {
        LazyVGrid(columns: choiceColumns(minimum: 96, large: typeSize.isAccessibilitySize), spacing: 10) {
            ForEach(offers) { offer in card(offer) }
        }
        Button(buying ? "Working…" : buyTitle) { buy() }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(buying || store.offers.isEmpty)
    }

    private var buyTitle: String { Self.buyTitle(selected, offer: store.offers.first { $0.productID == selected }) }

    /// Trial wording only when StoreKit says this product has a free trial this user can still have, in StoreKit's period.
    static func buyTitle(_ id: StoreKitManager.ProductID, offer: StoreKitManager.Offer?) -> String {
        if id == .lifetime { return String(localized: "Buy Forever") }
        if offer?.intro == .freeTrial, let trial = offer?.trialPeriod { return String(localized: "Start \(trial) Free") }
        return String(localized: "Subscribe")
    }

    /// Wraps at accessibility sizes; side by side would push the links off a phone.
    private var links: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 16))
        return VStack(alignment: .leading, spacing: 8) {
            layout {
                Button("Restore Purchases") { Task { await store.restore() } }
                Button("Manage Subscription") { showManage = true }
                Button("Redeem Offer") { showRedeem = true }
            }
            layout {
                Link("Terms of Use", destination: URL(string: SiteLinks.terms)!)
                Link("Privacy Policy", destination: URL(string: SiteLinks.privacy)!)
            }
        }
        .font(.footnote)
        .buttonStyle(QuietButtonStyle())
    }

    /// StoreKit's offers, or empty cards with a dash until StoreKit answers, so the layout never flashes. No price is made up.
    private var offers: [StoreKitManager.Offer] {
        store.offers.isEmpty
            ? StoreKitManager.ProductID.allCases.map { .init(productID: $0, displayPrice: "—", period: "", intro: nil) }
            : store.offers
    }

    private func card(_ offer: StoreKitManager.Offer) -> some View {
        let isSelected = selected == offer.productID
        let best = offer.productID == .yearly
        let period = offer.productID == .lifetime ? String(localized: "one payment") : offer.period
        return Button { selected = offer.productID } label: {
            ChoiceCard(title: offer.productID.title, detail: offer.badge, reservesDetail: true, aspect: 1, selected: isSelected) {
                VStack(spacing: 4) {
                    Text(LocalizedStringKey(best ? "Best value" : " ")).font(.caption2.weight(.bold)).foregroundStyle(AppTheme.accent)
                    Text(offer.displayPrice).font(.system(.title3, design: .monospaced).weight(.semibold))
                    Text(period).font(.caption).foregroundStyle(AppTheme.muted)
                }
                .lineLimit(1).minimumScaleFactor(0.5)
                .padding(6)
                .foregroundStyle(AppTheme.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text([String(localized: String.LocalizationValue(offer.productID.title)), offer.displayPrice, period,
                                  offer.badge ?? "", best ? String(localized: "Best value") : ""]
                                    .filter { !$0.isEmpty }.joined(separator: ", ")))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("pro.\(offer.productID.title)")
    }

    private func buy() {
        buying = true
        Task {
            let ok = await store.purchase(selected)
            buying = false
            if ok { dismiss() }
        }
    }
}
#endif
