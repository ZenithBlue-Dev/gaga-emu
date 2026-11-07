import Foundation
import StoreKit

/// StoreKit 2. Three products: monthly, annual, lifetime.
/// Premium unlocks the items in docs/06 section 4.3.
@MainActor
public final class StoreKitManager: ObservableObject {

    public enum ProductID: String, CaseIterable, Sendable {
        case monthly = "monthly.sub"
        case annual = "annual.sub"
        case lifetime = "lifetime.pass"

        public var isSubscription: Bool { self != .lifetime }
        public var title: String {
            switch self {
            case .monthly: return "Monthly Membership"
            case .annual: return "Annual Membership"
            case .lifetime: return "Lifetime Pass"
            }
        }
    }

    /// An introductory offer the user can actually redeem on this product.
    public enum IntroOffer: Equatable, Sendable { case freeTrial, paid }

    public struct Offer: Identifiable, Equatable, Sendable {
        public var id: String { productID.rawValue }
        public let productID: ProductID
        public let displayPrice: String
        public let price: Decimal
        public let periodSuffix: String
        public var intro: IntroOffer?
        public let subtitle: String?
        public var badge: String? { StoreKitManager.badge(for: productID, intro: intro) }
        public var disclosure: String? { StoreKitManager.disclosure(for: productID, intro: intro) }
    }

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
    }

    /// Sell only what works: anime4k and crt-royale return with milestone 3.4.
    public static let premiumShaderIDs: Set<String> = ["geom-crt", "geom-crt-border"]

    @Published public private(set) var offers: [Offer] = []
    @Published public private(set) var entitlements: Entitlements = .free
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
            entitlements = await Self.currentEntitlements()
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
                return entitlements.premium
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
        try? await AppStore.sync()
        entitlements = await Self.currentEntitlements()
    }

    // MARK: Gates

    public func canAddSaveState(current count: Int) -> Bool { count < entitlements.maxSaveStates }
    public func canAddCheat(current count: Int) -> Bool { count < entitlements.maxCheats }
    public var canUseAutoSaveState: Bool { entitlements.autoSaveState }
    public func canUseShader(_ id: String) -> Bool {
        entitlements.premiumShaders || !Self.premiumShaderIDs.contains(id)
    }

    // MARK: Transactions

    private func handle(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            await transaction.finish()
        case .unverified:
            break
        }
        entitlements = await Self.currentEntitlements()
    }

    /// Current entitlement wins. Revoked, expired, or upgraded transactions do not count.
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

    static func offer(from product: Product, intro: IntroOffer?) -> Offer? {
        guard let id = ProductID(rawValue: product.id) else { return nil }
        switch id {
        case .annual:
            let perMonth = product.price / 12
            let code = product.priceFormatStyle.currencyCode
            return Offer(productID: id, displayPrice: product.displayPrice, price: product.price,
                         periodSuffix: "/year", intro: intro,
                         subtitle: "(\(perMonth.formatted(.currency(code: code)))/month)")
        case .monthly:
            return Offer(productID: id, displayPrice: product.displayPrice, price: product.price,
                         periodSuffix: "/month", intro: intro, subtitle: nil)
        case .lifetime:
            return Offer(productID: id, displayPrice: product.displayPrice, price: product.price,
                         periodSuffix: "", intro: nil, subtitle: nil)
        }
    }

    /// Offer badges appear only when the product has that offer (docs/06 section 4.4).
    static func badge(for id: ProductID, intro: IntroOffer?) -> String? {
        if id == .lifetime { return "Best Value" }
        switch intro {
        case .freeTrial: return "Free Trial"
        case .paid: return "Introductory Offer"
        case nil: return nil
        }
    }

    /// Text under the offers. It must match what the selected product actually offers.
    static func disclosure(for id: ProductID, intro: IntroOffer?) -> String? {
        guard id.isSubscription else { return nil }
        return intro == .freeTrial ? "No charges during trial period. Cancel anytime" : "Cancel anytime"
    }

    private func rank(_ offer: Offer) -> Int {
        switch offer.productID {
        case .annual: return 0
        case .monthly: return 1
        case .lifetime: return 2
        }
    }
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
