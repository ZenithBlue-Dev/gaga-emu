import Foundation
import StoreKit

/// StoreKit 2. Three products: monthly, annual (shown as 50% off), lifetime.
/// Premium unlocks unlimited save states, unlimited cheats, and premium shaders.
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

    public struct Offer: Identifiable, Equatable, Sendable {
        public var id: String { productID.rawValue }
        public let productID: ProductID
        public let displayPrice: String
        public let price: Decimal
        public let periodSuffix: String
        public let badge: String?
        public let subtitle: String?
    }

    /// What a free account is allowed to do. Premium lifts all three caps.
    public struct Entitlements: Equatable, Sendable {
        public var premium: Bool
        public var maxSaveStates: Int { premium ? .max : 3 }
        public var maxCheats: Int { premium ? .max : 3 }
        public var maxFastForward: Double { premium ? 5 : 2 }
        public var premiumShaders: Bool { premium }
        public static let free = Entitlements(premium: false)
    }

    public static let premiumShaderIDs: Set<String> = [
        "geom-crt", "geom-crt-border", "anime4k", "crt-royale"
    ]

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
            offers = products.compactMap(Self.offer(from:)).sorted { rank($0) < rank($1) }
            entitlements = Entitlements(premium: await Self.hasPremium())
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
        entitlements = Entitlements(premium: await Self.hasPremium())
    }

    // MARK: Gates

    public func canAddSaveState(current count: Int) -> Bool { count < entitlements.maxSaveStates }
    public func canAddCheat(current count: Int) -> Bool { count < entitlements.maxCheats }
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
        entitlements = Entitlements(premium: await Self.hasPremium())
    }

    /// Current entitlement wins. Revoked, expired, or upgraded transactions do not count.
    static func hasPremium() async -> Bool {
        let ids = Set(ProductID.allCases.map(\.rawValue))
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, ids.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil { return true }
        }
        return false
    }

    static func offer(from product: Product) -> Offer? {
        guard let id = ProductID(rawValue: product.id) else { return nil }
        switch id {
        case .annual:
            let perMonth = product.price / 12
            let code = product.priceFormatStyle.currencyCode
            return Offer(productID: id, displayPrice: product.displayPrice, price: product.price,
                         periodSuffix: "/year", badge: "50% Off",
                         subtitle: "(\(perMonth.formatted(.currency(code: code)))/month)")
        case .monthly:
            return Offer(productID: id, displayPrice: product.displayPrice, price: product.price,
                         periodSuffix: "/month", badge: "Introductory Offer", subtitle: nil)
        case .lifetime:
            return Offer(productID: id, displayPrice: product.displayPrice, price: product.price,
                         periodSuffix: "", badge: "Best Value", subtitle: nil)
        }
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
