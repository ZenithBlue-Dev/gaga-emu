import Foundation
#if !GAGA_SIDELOAD
import StoreKit
#endif

// The sideload core set (GAGA_SIDELOAD, scripts/generate-project.sh) holds cores whose licences forbid
// commercial use (docs/03 section 5), so that build sells nothing: StoreKit, the products and every purchase
// path are compiled out, and every premium feature is free.
#if GAGA_SIDELOAD && PAYWALL_ENABLED
#error("A sideload build must not have a paywall: its non-commercial cores forbid selling it (docs/03 section 5).")
#endif

/// Paywall release gate (docs/06 section 4.5). Add the PAYWALL_ENABLED compilation condition in
/// project.yml only when milestone 7.2 opens it. While closed: no Gaga Plus category, no premium labels, no limits.
public enum PaywallGate {
    #if PAYWALL_ENABLED
    public static let isOpen = true
    #else
    public static let isOpen = false
    #endif

    /// Settings shows GagaEmu Pro while the gate is open, and in Debug builds so the paywall can be checked and shot
    /// before then. A Release build with the gate closed sells nothing, because nothing is held back yet.
    public static var showsPro: Bool {
        #if GAGA_SIDELOAD
        return false
        #elseif DEBUG
        return true
        #else
        return isOpen
        #endif
    }
}

/// StoreKit 2. GagaEmu Pro: monthly and yearly subscriptions in one group, and Forever, a one-time purchase.
/// Premium unlocks the items in docs/06 section 4.3.
@MainActor
public final class StoreKitManager: ObservableObject {

    #if !GAGA_SIDELOAD
    /// The App Store Connect product IDs, matched by Resources/GagaEmuPro.storekit (checked by a unit test).
    public enum ProductID: String, CaseIterable, Sendable {
        case monthly = "com.zenithblue.gagaemu.pro.monthly"
        case yearly = "com.zenithblue.gagaemu.pro.yearly"
        case lifetime = "com.zenithblue.gagaemu.pro.lifetime"

        public var isSubscription: Bool { self != .lifetime }
        public var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            case .lifetime: return "Forever"
            }
        }
    }

    /// An introductory offer the user can actually redeem on this product.
    public enum IntroOffer: Equatable, Sendable { case freeTrial, paid }

    public struct Offer: Identifiable, Equatable, Sendable {
        public var id: String { productID.rawValue }
        public let productID: ProductID
        public let displayPrice: String
        /// StoreKit's renewal period, such as "1 month"; empty for Forever.
        public let period: String
        public var intro: IntroOffer?
        /// StoreKit's free trial length, such as "1 week", when this user can still have it.
        public var trialPeriod: String?
        public var badge: String? { StoreKitManager.badge(for: productID, intro: intro, trialPeriod: trialPeriod) }
    }
    #endif

    /// What a free account is allowed to do. Premium lifts every limit.
    public struct Entitlements: Equatable, Sendable {
        public var premium: Bool
        public var lifetime = false
        public var maxSaveStates: Int { premium ? .max : 3 }
        public var maxCheats: Int { premium ? .max : 3 }
        public var maxFastForward: Double { premium ? 5 : 2 }
        public var premiumShaders: Bool { premium }
        public var autoSaveState: Bool { premium }
        /// Lifetime owners have nothing left to buy (docs/06 section 4.4).
        public var showsSubscribePrompts: Bool { !lifetime }
        public static let free = Entitlements(premium: false)

        public func canAddSaveState(current count: Int) -> Bool { count < maxSaveStates }
        public func canAddCheat(current count: Int) -> Bool { count < maxCheats }

        /// What the app enforces: the purchases, or no limits at all while the gate is closed.
        static func effective(_ purchased: Entitlements, gateOpen: Bool = PaywallGate.isOpen) -> Entitlements {
            gateOpen ? purchased : Entitlements(premium: true)
        }
    }

    /// Sell only what works. crt-deluxe replaces crt-royale, which is GPL (docs/05 section 5).
    public static let premiumShaderIDs: Set<String> = ["geom-crt", "geom-crt-border", "crt-deluxe", "anime4k"]

    #if GAGA_SIDELOAD
    /// Everything, always, with nothing to buy and no subscribe prompts.
    @Published public private(set) var entitlements = Entitlements(premium: true, lifetime: true)
    public var isPro: Bool { true }

    public init() {}
    #else
    @Published public private(set) var offers: [Offer] = []
    @Published public private(set) var entitlements: Entitlements = .effective(.free)
    /// What this Apple Account has bought, verified, whatever the gate says. Nothing reads it to lock a feature yet.
    @Published public private(set) var purchased: Entitlements = .free
    public var isPro: Bool { purchased.premium }
    @Published public private(set) var isLoading = false
    @Published public var lastError: String?

    private var updates: Task<Void, Never>?

    public init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refresh() }
    }

    deinit { updates?.cancel() }

    // MARK: Storefront

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            var loaded: [Offer] = []
            for product in products {
                if let offer = Self.offer(from: product, intro: await Self.intro(of: product)) { loaded.append(offer) }
            }
            offers = loaded.sorted { rank($0) < rank($1) }
            await updateEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func purchase(_ productID: ProductID) async -> Bool {
        guard let product = try? await Product.products(for: [productID.rawValue]).first else {
            lastError = "Product unavailable."
            return false
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
                return purchased.premium
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    public func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await updateEntitlements()
    }
    #endif

    // MARK: Gates

    public var canUseAutoSaveState: Bool { entitlements.autoSaveState }
    public func canUseShader(_ id: String) -> Bool {
        entitlements.premiumShaders || !Self.premiumShaderIDs.contains(id)
    }

    #if !GAGA_SIDELOAD
    // MARK: Transactions

    private func handle(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            await transaction.finish()
        case .unverified:
            break
        }
        await updateEntitlements()
    }

    private func updateEntitlements() async {
        purchased = await Self.currentEntitlements()
        entitlements = .effective(purchased)
    }

    /// What was bought, before the gate. Only verified transactions count; revoked, expired, or upgraded ones do not.
    static func currentEntitlements() async -> Entitlements {
        let ids = Set(ProductID.allCases.map(\.rawValue))
        var current = Entitlements.free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, ids.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            current.premium = true
            if transaction.productID == ProductID.lifetime.rawValue { current.lifetime = true }
        }
        return current
    }

    /// The offer App Store Connect has configured, if this user is still eligible for it.
    static func intro(of product: Product) async -> IntroOffer? {
        guard let subscription = product.subscription, let offer = subscription.introductoryOffer,
              await subscription.isEligibleForIntroOffer else { return nil }
        return offer.paymentMode == .freeTrial ? .freeTrial : .paid
    }

    /// Price and periods come from StoreKit, never from the app.
    static func offer(from product: Product, intro: IntroOffer?) -> Offer? {
        guard let id = ProductID(rawValue: product.id) else { return nil }
        let subscription = product.subscription
        let trial = intro == .freeTrial ? subscription?.introductoryOffer.map { periodText($0.period) } : nil
        return Offer(productID: id, displayPrice: product.displayPrice,
                     period: subscription.map { periodText($0.subscriptionPeriod) } ?? "",
                     intro: id.isSubscription ? intro : nil, trialPeriod: trial)
    }

    /// A StoreKit period in words in the user's language, such as "1 week" or "1 year".
    nonisolated static func periodText(_ period: Product.SubscriptionPeriod) -> String {
        var parts = DateComponents()
        switch period.unit {
        case .day: parts.day = period.value
        case .week: parts.weekOfMonth = period.value
        case .month: parts.month = period.value
        case .year: parts.year = period.value
        @unknown default: parts.day = period.value
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .weekOfMonth, .month, .year]
        return formatter.string(from: parts) ?? ""
    }

    /// Offer badges appear only when the product has that offer (docs/06 section 4.4).
    nonisolated static func badge(for id: ProductID, intro: IntroOffer?, trialPeriod: String? = nil) -> String? {
        if id == .lifetime { return String(localized: "One payment") }
        switch intro {
        case .freeTrial: return trialPeriod.map { String(localized: "\($0) free") } ?? String(localized: "Free Trial")
        case .paid: return String(localized: "Introductory Offer")
        case nil: return nil
        }
    }

    private func rank(_ offer: Offer) -> Int {
        switch offer.productID {
        case .monthly: return 0
        case .yearly: return 1
        case .lifetime: return 2
        }
    }
    #endif
}

#if DEBUG
enum StoreKitManagerChecks {
    static func run() {
        let free = StoreKitManager.Entitlements.free
        assert(free.maxSaveStates == 3)
        assert(free.maxCheats == 3)
        assert(!free.premiumShaders)
        let premium = StoreKitManager.Entitlements(premium: true)
        assert(premium.maxSaveStates == .max)
        assert(premium.maxFastForward == 5)
        assert(!StoreKitManager.premiumShaderIDs.contains("original"))
        assert(StoreKitManager.premiumShaderIDs.contains("geom-crt"))
    }
}
#endif
