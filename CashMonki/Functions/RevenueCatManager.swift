//
//  RevenueCatManager.swift
//  CashMonki
//
//  Standard RevenueCat implementation
//

import Foundation
import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

// MARK: - Premium Features

enum PremiumFeature {
    case unlimitedTransactions
    case advancedAnalytics
    case cloudSync
    case exportData
    case customCategories
}

// MARK: - RevenueCat Manager

#if canImport(RevenueCat)
@MainActor
class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()

    // MARK: - Published Properties

    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isSubscriptionActive: Bool = false

    // MARK: - Configuration

    private var isConfigured: Bool = false

    // Entitlement identifier from RevenueCat dashboard
    private let entitlementID = "cashmonki-subs"

    // MARK: - Computed Properties

    /// Check if user has Pro subscription
    var isProUser: Bool {
        return isSubscriptionActive
    }

    /// Get current offering for paywall
    var currentOffering: Offering? {
        return offerings?.current
    }

    /// Legacy compatibility - same as currentOffering
    var targetOffering: Offering? {
        return currentOffering
    }

    /// Check if user has used trial before but isn't currently subscribed
    var hasUsedTrialBefore: Bool {
        guard let customerInfo = customerInfo else { return false }

        // If currently subscribed, they're not a "lapsed" user
        if isProUser { return false }

        // Check if user has any previous purchases (indicating they used trial before)
        let hasAnyPurchases = !customerInfo.allPurchasedProductIdentifiers.isEmpty

        // Also check if they have any entitlements (active or inactive)
        let hasAnyEntitlements = !customerInfo.entitlements.all.isEmpty

        // User is "lapsed" if they have purchase history or entitlements but aren't currently active
        return hasAnyPurchases || hasAnyEntitlements
    }

    /// Debug property to show what offerings are actually available
    var debugAvailableOfferingIds: [String] {
        return offerings?.all.keys.sorted() ?? []
    }

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    // MARK: - Configuration

    nonisolated func configure() {
        Task { @MainActor in
            await configureRevenueCat()
        }
    }

    private func configureRevenueCat() async {
        guard !isConfigured else {
            print("✅ RevenueCat: Already configured")
            return
        }

        // Get API key from Info.plist
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              !apiKey.isEmpty else {
            print("❌ RevenueCat: No API key found in Info.plist")
            return
        }

        print("🔑 RevenueCat: Configuring with API key: \(apiKey.prefix(15))...")

        // Configure RevenueCat
        Purchases.logLevel = .debug

        let configuration = Configuration.Builder(withAPIKey: apiKey)
            .with(purchasesAreCompletedBy: .revenueCat, storeKitVersion: .storeKit2)
            .build()

        Purchases.configure(with: configuration)
        Purchases.shared.delegate = self

        isConfigured = true
        print("✅ RevenueCat: Configuration complete")

        // Load initial data
        await loadCustomerInfo()
        await loadOfferings()
    }

    // MARK: - Customer Info

    func loadCustomerInfo() async {
        guard isConfigured else {
            print("⚠️ RevenueCat: Not configured - call configure() first")
            return
        }

        do {
            let info = try await Purchases.shared.customerInfo()
            customerInfo = info
            updateSubscriptionStatus(info)
            print("✅ RevenueCat: Customer info loaded")
        } catch {
            print("❌ RevenueCat: Failed to load customer info - \(error.localizedDescription)")
        }
    }

    func forceRefreshCustomerInfo() async {
        await loadCustomerInfo()
    }

    private func updateSubscriptionStatus(_ info: CustomerInfo) {
        // Check for active entitlement
        let hasEntitlement = info.entitlements[entitlementID]?.isActive == true
        isSubscriptionActive = hasEntitlement

        print("💰 RevenueCat: Subscription active: \(isSubscriptionActive)")

        if !info.entitlements.active.isEmpty {
            print("✅ Active entitlements:")
            for (id, entitlement) in info.entitlements.active {
                print("   - \(id): expires \(entitlement.expirationDate?.description ?? "never")")
            }
        }
    }

    // MARK: - Offerings

    func loadOfferings() async {
        guard isConfigured else {
            print("⚠️ RevenueCat: Not configured - call configure() first")
            return
        }

        do {
            let loadedOfferings = try await Purchases.shared.offerings()
            offerings = loadedOfferings

            if let current = loadedOfferings.current {
                print("✅ RevenueCat: Loaded offering '\(current.identifier)' with \(current.availablePackages.count) packages")
                for package in current.availablePackages {
                    print("   📦 \(package.storeProduct.localizedTitle) - \(package.storeProduct.localizedPriceString)")
                }
            } else {
                print("⚠️ RevenueCat: No current offering available")
            }
        } catch {
            print("❌ RevenueCat: Failed to load offerings - \(error.localizedDescription)")
        }
    }

    // MARK: - Purchases

    func purchase(package: Package) async -> (success: Bool, error: Error?) {
        guard isConfigured else {
            let error = NSError(domain: "RevenueCat", code: -1, userInfo: [NSLocalizedDescriptionKey: "RevenueCat not configured"])
            return (false, error)
        }

        print("💳 RevenueCat: Purchasing \(package.storeProduct.localizedTitle)...")

        do {
            let result = try await Purchases.shared.purchase(package: package)

            if !result.userCancelled {
                customerInfo = result.customerInfo
                updateSubscriptionStatus(result.customerInfo)
                print("✅ RevenueCat: Purchase successful")
                return (true, nil)
            } else {
                print("⏹️ RevenueCat: Purchase cancelled by user")
                return (false, nil)
            }
        } catch {
            print("❌ RevenueCat: Purchase failed - \(error.localizedDescription)")
            return (false, error)
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async -> (success: Bool, error: Error?) {
        guard isConfigured else {
            let error = NSError(domain: "RevenueCat", code: -1, userInfo: [NSLocalizedDescriptionKey: "RevenueCat not configured"])
            return (false, error)
        }

        print("🔄 RevenueCat: Restoring purchases...")

        do {
            let info = try await Purchases.shared.restorePurchases()
            customerInfo = info
            updateSubscriptionStatus(info)
            print("✅ RevenueCat: Purchases restored")
            return (true, nil)
        } catch {
            print("❌ RevenueCat: Restore failed - \(error.localizedDescription)")
            return (false, error)
        }
    }

    // MARK: - User Identity

    func identifyUser(userId: String) async {
        guard isConfigured else {
            print("⚠️ RevenueCat: Not configured - call configure() first")
            return
        }

        do {
            let result = try await Purchases.shared.logIn(userId)
            customerInfo = result.customerInfo
            updateSubscriptionStatus(result.customerInfo)
            print("✅ RevenueCat: User identified - created: \(result.created)")
        } catch {
            print("❌ RevenueCat: Failed to identify user - \(error.localizedDescription)")
        }
    }

    func logoutUser() async {
        guard isConfigured else {
            print("⚠️ RevenueCat: Not configured - call configure() first")
            return
        }

        do {
            let info = try await Purchases.shared.logOut()
            customerInfo = info
            updateSubscriptionStatus(info)
            print("✅ RevenueCat: User logged out")
        } catch {
            print("❌ RevenueCat: Logout failed - \(error.localizedDescription)")
        }
    }

    // MARK: - Feature Checks

    func hasFeature(_ feature: PremiumFeature) -> Bool {
        return isSubscriptionActive
    }

    // MARK: - Debug Methods (for development only)

    #if DEBUG
    /// Enable test premium features for debugging
    func enableTestPremium() {
        isSubscriptionActive = true
        print("🧪 RevenueCat: Test premium enabled")
    }

    /// Disable test premium features
    func disableTestPremium() {
        isSubscriptionActive = false
        print("🧪 RevenueCat: Test premium disabled")
    }

    /// Force lapsed trial state for testing (no-op in simplified version)
    func forceDebugLapsedTrial() {
        print("🧪 RevenueCat: Force lapsed trial (simplified - no effect)")
    }

    /// Force new user state for testing (no-op in simplified version)
    func forceDebugNewUser() {
        print("🧪 RevenueCat: Force new user (simplified - no effect)")
    }

    /// Reset debug trial state (no-op in simplified version)
    func resetDebugTrialState() {
        print("🧪 RevenueCat: Reset trial state (simplified - no effect)")
    }
    #endif
}

// MARK: - Purchases Delegate

extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.updateSubscriptionStatus(customerInfo)
            print("🔄 RevenueCat: Customer info updated")
        }
    }
}

#else
// MARK: - Fallback Implementation (when RevenueCat is not available)

class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()

    @Published var customerInfo: Any? = nil
    @Published var offerings: Any? = nil
    @Published var isSubscriptionActive: Bool = false

    var isProUser: Bool { false }
    var currentOffering: Any? { nil }
    var targetOffering: Any? { nil }
    var hasUsedTrialBefore: Bool { false }
    var debugAvailableOfferingIds: [String] { [] }

    override private init() {}

    func configure() {
        print("❌ RevenueCat: Not available")
    }

    func loadCustomerInfo() async {}
    func loadOfferings() async {}

    func purchase(package: Any) async -> (success: Bool, error: Error?) {
        return (false, nil)
    }

    func restorePurchases() async -> (success: Bool, error: Error?) {
        return (false, nil)
    }

    func identifyUser(userId: String) async {}
    func logoutUser() async {}

    func hasFeature(_ feature: PremiumFeature) -> Bool {
        return false
    }

    #if DEBUG
    func enableTestPremium() {}
    func disableTestPremium() {}
    func forceDebugLapsedTrial() {}
    func forceDebugNewUser() {}
    func resetDebugTrialState() {}
    #endif
}

#endif
