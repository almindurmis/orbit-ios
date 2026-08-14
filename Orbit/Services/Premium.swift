import Foundation
import StoreKit

// Orbit Premium (auto-renewing subscription). Entitlement state is cached in
// UserDefaults so non-observing call sites (the SpriteKit scene, missions) can
// check synchronously; StoreKit 2 keeps it honest on every launch and update.
@MainActor
final class Premium: ObservableObject {
    static let shared = Premium()

    static let productIDs = [
        "online.foundry7.orbit.premium.monthly",
        "online.foundry7.orbit.premium.yearly",
    ]

    private static let cacheKey = "premium.active"

    @Published private(set) var isActive = Premium.isActiveNow
    @Published private(set) var products: [Product] = []

    /// Synchronous check for game-loop call sites. `-premium` forces it on for
    /// development and screenshot runs.
    nonisolated static var isActiveNow: Bool {
        if ProcessInfo.processInfo.arguments.contains("-premium") { return true }
        return UserDefaults.standard.bool(forKey: cacheKey)
    }

    private var updatesTask: Task<Void, Never>?

    func start() {
        updatesTask = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refresh()
            }
        }
        Task {
            await loadProducts()
            await refresh()
        }
    }

    func loadProducts() async {
        let loaded = (try? await Product.products(for: Self.productIDs)) ?? []
        products = loaded.sorted { $0.price < $1.price }
    }

    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isActive = active || ProcessInfo.processInfo.arguments.contains("-premium")
        UserDefaults.standard.set(active, forKey: Self.cacheKey)
    }

    func purchase(_ product: Product) async {
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
            await refresh()
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }
}
