import SwiftUI

/// Paywall. Annual is preselected, matching 0596EA12. Badges reflect configured offers only.
struct MembershipPaywallView: View {
    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var selected: StoreKitManager.ProductID = .annual
    @State private var buying = false
    @State private var showRedeem = false

    private let perks: [(String, String)] = [
        ("forward.fill", "5x Speed"),
        ("square.stack.fill", "Unlimited Save States"),
        ("chevron.left.forwardslash.chevron.right", "Unlimited Cheat Codes"),
        ("circle.grid.hex.fill", "Premium Filters"),
        ("arrow.clockwise", "Auto Save State")
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    if store.entitlements.showsSubscribePrompts {
                        ForEach(ordered) { offer in offerRow(offer) }
                        if let disclosure = ordered.first(where: { $0.productID == selected })?.disclosure {
                            Text(disclosure)
                                .font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary).padding(.top, 8)
                        }
                        Button { buy() } label: {
                            Text(buying ? "Working…" : cta)
                                .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(AppTheme.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(buying || store.offers.isEmpty && !store.isLoading)
                    } else {
                        Text("Your Lifetime Pass is active.")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).padding(.vertical, 8)
                    }
                    Text("Premium Filters apply only to cores that use the host shader chain.")
                        .font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 8) {
                        Link("Terms of Service", destination: URL(string: SiteLinks.terms)!)
                        Text("|").foregroundStyle(AppTheme.textTertiary)
                        Link("Privacy Policy", destination: URL(string: SiteLinks.privacy)!)
                    }
                    .font(.system(size: 12)).foregroundStyle(AppTheme.textSecondary)
                    if let error = store.lastError {
                        Text(error).font(.system(size: 12)).foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(16)
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .task { await store.refresh() }
        .offerCodeRedemption(isPresented: $showRedeem) { _ in
            Task { await store.refresh() }
        }
    }

    private var header: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [.orange, .pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 280)
            VStack(spacing: 14) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34).background(.white.opacity(0.2), in: Circle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Close")
                    Spacer()
                    Button("Redeem Offer") { showRedeem = true }.buttonStyle(.plain)
                    Button("Restore Purchases") { Task { await store.restore() } }.buttonStyle(.plain)
                }
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).padding(.horizontal, 16)
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                    Text("Unlock Premium Features").font(.system(size: 22, weight: .bold))
                    Image(systemName: "leaf.fill")
                }
                .foregroundStyle(.white)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(perks, id: \.1) { perk in
                        VStack(spacing: 6) {
                            Image(systemName: perk.0).font(.system(size: 18))
                            Text(perk.1).font(.system(size: 11, weight: .medium)).multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
        }
    }

    private var ordered: [StoreKitManager.Offer] {
        if store.offers.isEmpty { return Self.placeholders }
        return store.offers
    }

    private func offerRow(_ offer: StoreKitManager.Offer) -> some View {
        Button { selected = offer.productID } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.productID == .lifetime ? "Lifetime Pass · One-time Payment" : offer.productID.title)
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(offer.displayPrice).font(.system(size: 26, weight: .heavy))
                        Text(offer.periodSuffix).font(.system(size: 14))
                        if let subtitle = offer.subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(AppTheme.textSecondary) }
                    }
                }
                Spacer()
                if let badge = offer.badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(badgeColor(offer), in: Capsule())
                }
            }
            .padding(14)
            .foregroundStyle(.white)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected == offer.productID ? AppTheme.accent : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func badgeColor(_ offer: StoreKitManager.Offer) -> Color {
        switch offer.productID {
        case .annual: return AppTheme.accent
        case .monthly: return AppTheme.accentGreen
        case .lifetime: return AppTheme.warning
        }
    }

    private var cta: String { selected == .lifetime ? "Buy Lifetime Pass" : "Subscribe Now" }

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
        .init(productID: .annual, displayPrice: "—", price: 0, periodSuffix: "/year", intro: nil, subtitle: nil),
        .init(productID: .monthly, displayPrice: "—", price: 0, periodSuffix: "/month", intro: nil, subtitle: nil),
        .init(productID: .lifetime, displayPrice: "—", price: 0, periodSuffix: "", intro: nil, subtitle: nil)
    ]
}
