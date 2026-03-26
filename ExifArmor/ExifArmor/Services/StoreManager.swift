import Foundation
import StoreKit

/// Manages the single "Pro" in-app purchase using StoreKit 2.
@MainActor
@Observable
final class StoreManager {

    nonisolated static let proProductID = "com.katafract.ExifArmor.Pro"
    nonisolated static let tipProductIDs = [
        "com.katafract.ExifArmor.Tip.Small",
        "com.katafract.ExifArmor.Tip.Medium",
        "com.katafract.ExifArmor.Tip.Large",
    ]
    nonisolated static let appGroupID = "group.com.katafract.exifarmor"
    nonisolated static let sharedProAccessKey = "sharedProAccessUnlocked"

    private(set) var proProduct: Product?
    private(set) var tipProducts: [Product] = []
    private(set) var isPro: Bool = false {
        didSet {
            persistSharedProAccess()
        }
    }
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var bundleIdentifier: String
    private(set) var appTransactionEnvironmentDescription = "Unknown"
    private(set) var appTransactionBundleID = "Unknown"
    private(set) var testingModeDescription = "Unknown"
    private(set) var lastLoadAttempt = 0
    private(set) var lastProductCount = 0
    private(set) var lastLoadError = "None"
    private(set) var debugLog: [String] = []

    private var updateListenerTask: Task<Void, Never>?
    private var hasLoadedProducts = false

    init() {
        bundleIdentifier = Bundle.main.bundleIdentifier ?? "nil"
        appendDebugLog("init bundle=\(bundleIdentifier)")
        persistSharedProAccess()

        // Start listening for transaction updates (renewals, refunds, etc.)
        updateListenerTask = listenForTransactionUpdates()

        // Check existing entitlements on launch
        Task {
            await checkExistingPurchases()
            await ensureProductsLoaded()
        }
    }

    // MARK: - Load Products

    func ensureProductsLoaded() async {
        guard !hasLoadedProducts, !isLoading else { return }
        await loadProducts()
    }

    func loadProducts() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        errorMessage = nil
        lastLoadAttempt = 0
        lastProductCount = 0
        lastLoadError = "None"
        appendDebugLog("loadProducts start productID=\(Self.proProductID)")

        // Log AppStore environment
        do {
            let appTransaction = try await AppTransaction.shared
            switch appTransaction {
            case .verified(let tx):
                appTransactionEnvironmentDescription = "\(tx.environment)"
                appTransactionBundleID = tx.bundleID
                testingModeDescription = testingMode(for: tx.environment)
                appendDebugLog("AppTransaction verified env=\(tx.environment) bundleID=\(tx.bundleID)")
            case .unverified(let tx, let error):
                appTransactionEnvironmentDescription = "\(tx.environment) (unverified)"
                appTransactionBundleID = tx.bundleID
                testingModeDescription = testingMode(for: tx.environment)
                lastLoadError = "AppTransaction unverified: \(error.localizedDescription)"
                appendDebugLog("AppTransaction unverified env=\(tx.environment) error=\(error.localizedDescription)")
            }
        } catch {
            appTransactionEnvironmentDescription = "Unavailable"
            appTransactionBundleID = "Unavailable"
            testingModeDescription = "Unavailable"
            lastLoadError = "AppTransaction error: \(error.localizedDescription)"
            appendDebugLog("AppTransaction error=\(error.localizedDescription)")
        }

        // Retry up to 3 times with a short delay — StoreKit can be slow to initialise
        for attempt in 1...3 {
            lastLoadAttempt = attempt
            do {
                let products = try await Product.products(for: [Self.proProductID])
                let tips = try await Product.products(for: Self.tipProductIDs)
                lastProductCount = products.count
                tipProducts = tips.sorted { $0.price < $1.price }
                appendDebugLog("Attempt \(attempt) returned \(products.count) product(s)")
                products.forEach {
                    self.appendDebugLog("Product id=\($0.id) name=\($0.displayName) price=\($0.displayPrice)")
                }
                if !products.isEmpty {
                    proProduct = products.first
                    hasLoadedProducts = true
                    errorMessage = nil
                    lastLoadError = "None"
                    appendDebugLog("loadProducts success")
                    return
                }
                lastLoadError = "Attempt \(attempt) returned zero products"
                appendDebugLog("Attempt \(attempt) returned zero products")
            } catch {
                lastLoadError = error.localizedDescription
                appendDebugLog("Attempt \(attempt) error=\(error.localizedDescription)")
            }
            if attempt < 3 {
                appendDebugLog("Waiting 2s before retry")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        errorMessage = "No products returned. Verify the ExifArmor run scheme uses ExifArmorProducts.storekit."
        appendDebugLog("loadProducts failed after 3 attempts")
    }

    // MARK: - Purchase

    func purchasePro() async -> Bool {
        if proProduct == nil {
            await ensureProductsLoaded()
        }

        guard let product = proProduct else {
            errorMessage = errorMessage ?? "Product not loaded — check StoreKit config"
            appendDebugLog("purchasePro aborted because proProduct is nil")
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPro = true
                appendDebugLog("purchasePro success")
                return true

            case .userCancelled:
                appendDebugLog("purchasePro cancelled by user")
                return false

            case .pending:
                errorMessage = "Purchase is pending approval"
                appendDebugLog("purchasePro pending approval")
                return false

            @unknown default:
                appendDebugLog("purchasePro unknown result")
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            appendDebugLog("purchasePro error=\(error.localizedDescription)")
            return false
        }
    }

    func purchaseTip(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            if case .success(let verification) = result {
                let transaction = try checkVerified(verification)
                await transaction.finish()
                return true
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }

        return false
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        // Sync with the App Store
        try? await AppStore.sync()
        await checkExistingPurchases()
        appendDebugLog("restorePurchases completed")
    }

    // MARK: - Private

    private func checkExistingPurchases() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID {
                isPro = true
                appendDebugLog("existing entitlement found for \(transaction.productID)")
                return
            }
        }
        appendDebugLog("no existing entitlement found")
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    if transaction.productID == Self.proProductID {
                        await MainActor.run {
                            self.isPro = !transaction.isUpgraded
                                && transaction.revocationDate == nil
                            self.appendDebugLog("transaction update productID=\(transaction.productID) active=\(self.isPro)")
                        }
                    }
                    await transaction.finish()
                }
            }
        }
    }

    private func appendDebugLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        debugLog.append("[\(timestamp)] \(message)")
        if debugLog.count > 20 {
            debugLog.removeFirst(debugLog.count - 20)
        }
        print("[StoreManager] \(message)")
    }

    private func persistSharedProAccess() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        defaults.set(isPro, forKey: Self.sharedProAccessKey)
    }

    private func testingMode(for environment: AppStore.Environment) -> String {
        switch environment {
        case .xcode:
            return "Xcode StoreKit testing. Sandbox Apple Account is not used while a .storekit file is attached to the run scheme."
        case .sandbox:
            return "Sandbox testing. Products must exist in App Store Connect, and the run scheme must not override StoreKit with a local .storekit file."
        case .production:
            return "Production App Store environment."
        default:
            return "Unknown StoreKit environment."
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
