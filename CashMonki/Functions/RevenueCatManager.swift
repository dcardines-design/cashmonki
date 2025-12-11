//
//  RevenueCatManager.swift
//  CashMonki
//
//  Created by Claude on 10/27/25.
//

import Foundation
import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(RevenueCat)
@MainActor
class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isSubscriptionActive: Bool = false
    
    // MARK: - Configuration State
    private var isConfigured: Bool = false
    
    // MARK: - Test Mode
    @Published var debugTestProEnabled: Bool = false  // Disable by default
    
    /// Enable test pro features for debugging (DEBUG builds only)
    func enableTestPro() {
        #if DEBUG
        debugTestProEnabled = true
        print("🧪 Test Pro mode enabled")
        #endif
    }
    
    /// Disable test pro features (DEBUG builds only)
    func disableTestPro() {
        #if DEBUG
        debugTestProEnabled = false
        print("🧪 Test Pro mode disabled")
        #endif
    }
    
    /// Convenience property to check if user has Pro subscription
    var isProUser: Bool {
        #if DEBUG
        // For testing without RevenueCat dashboard setup
        return debugTestProEnabled
        #else
        return isSubscriptionActive
        #endif
    }
    
    // MARK: - Debug Testing
    @Published var debugTrialState: DebugTrialState = .normal
    
    enum DebugTrialState {
        case normal          // Use real RevenueCat data
        case forceLapsed     // Force lapsed trial state
        case forceNew        // Force new user state
    }
    
    /// Check if user has used trial before but isn't currently subscribed
    var hasUsedTrialBefore: Bool {
        // DEBUG: Check debug state first
        switch debugTrialState {
        case .forceLapsed:
            return true
        case .forceNew:
            return false
        case .normal:
            break // Use real logic below
        }
        
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
    
    /// Reset debug trial state to normal
    func resetDebugTrialState() {
        debugTrialState = .normal
        print("🔧 DEBUG: Trial state reset to normal")
    }
    
    /// Force lapsed trial state for testing
    func forceDebugLapsedTrial() {
        debugTrialState = .forceLapsed
        print("🔧 DEBUG: Trial state forced to lapsed")
    }
    
    /// Force new user state for testing
    func forceDebugNewUser() {
        debugTrialState = .forceNew
        print("🔧 DEBUG: Trial state forced to new user")
    }
    
    // Offering ID from RevenueCat dashboard
    private let offeringID = "Cashmonki"  // Your actual offering ID from dashboard
    
    // Debug property to show what offerings are actually available
    var debugAvailableOfferingIds: [String] {
        return offerings?.all.keys.sorted() ?? []
    }
    
    /// Automatically detect the best offering ID based on what's available
    var smartOfferingID: String? {
        guard let offerings = offerings else { return nil }
        
        // Priority 1: Exact match "Cashmonki"
        if offerings.offering(identifier: "Cashmonki") != nil {
            return "Cashmonki"
        }
        
        // Priority 2: Case variations
        let variations = ["cashmonki", "CASHMONKI", "CashMonki", "cashMonki", "Cashmonki"]
        for variation in variations {
            if offerings.offering(identifier: variation) != nil {
                return variation
            }
        }
        
        // Priority 3: Contains "cash" anywhere
        for identifier in offerings.all.keys {
            if identifier.lowercased().contains("cash") {
                return identifier
            }
        }
        
        // Priority 4: Contains "monki" anywhere
        for identifier in offerings.all.keys {
            if identifier.lowercased().contains("monki") {
                return identifier
            }
        }
        
        // Priority 5: Current offering
        if let current = offerings.current {
            return current.identifier
        }
        
        // Priority 6: First available offering
        if let first = offerings.all.first?.key {
            return first
        }
        
        return nil
    }
    
    override private init() {}
    
    // MARK: - Configuration
    
    nonisolated func configure() {
        // Initialize API keys if not already in keychain
        #if DEBUG
        // Force use test API key in debug builds
        Config.useTestAPIKey()
        #else
        Config.initializeRevenueCatKey()
        #endif
        
        // Get RevenueCat API key from secure storage
        guard let apiKey = Config.revenueCatAPIKey else {
            print("❌ RevenueCat: No API key found in secure storage")
            print("💡 RevenueCat: For testing, configure API key in RevenueCat dashboard")
            print("💡 RevenueCat: Add your API key to Info.plist under 'RevenueCatAPIKey'")
            return
        }
        
        print("✅ RevenueCat: Configuring...")
        
        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.simulatesAskToBuyInSandbox = true
        print("🧪 RevenueCat: Debug mode enabled")
        #else
        Purchases.logLevel = .warn
        #endif
        
        #if DEBUG
        let config = Configuration.Builder(withAPIKey: apiKey)
            .with(purchasesAreCompletedBy: .revenueCat, storeKitVersion: .storeKit1)
            .with(storeKit1Timeout: 30)
            .build()
        #else
        let config = Configuration.Builder(withAPIKey: apiKey)
            .with(purchasesAreCompletedBy: .revenueCat, storeKitVersion: .storeKit1)
            .build()
        #endif
        
        Purchases.configure(with: config)
        print("✅ RevenueCat: Successfully configured")
        
        // CRITICAL FIX: Mark as configured to prevent crashes
        Task { @MainActor in
            self.isConfigured = true
        }
        
        // Set up delegate (must be set after configure)
        Purchases.shared.delegate = self
        
        // Load initial data
        Task { @MainActor in
            await loadCustomerInfo()
            await loadOfferings()
        }
    }
    
    // MARK: - Customer Info
    
    func loadCustomerInfo() async {
        print("👤 RevenueCat: Loading customer info...")
        
        // CRITICAL FIX: Ensure RevenueCat is configured before accessing Purchases.shared
        guard isConfigured else {
            print("❌ RevenueCat: Cannot load customer info - RevenueCat not configured")
            return
        }
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.customerInfo = customerInfo
                self.updateSubscriptionStatus(customerInfo)
                print("✅ RevenueCat: Customer info loaded successfully")
            }
        } catch {
            await MainActor.run {
                print("❌ RevenueCat: Failed to load customer info: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateSubscriptionStatus(_ customerInfo: CustomerInfo) {
        print("🔍 RevenueCat: ======= SUBSCRIPTION STATUS UPDATE =======")
        
        // Check if user has any active entitlements
        // Check for common entitlement names (case variations)
        let proEntitlement = customerInfo.entitlements["Pro"]?.isActive == true
        let premiumEntitlement = customerInfo.entitlements["premium"]?.isActive == true
        let cashmonkiProEntitlement = customerInfo.entitlements["Cashmonki Pro"]?.isActive == true
        let cashmonkiEntitlement = customerInfo.entitlements["Cashmonki"]?.isActive == true
        
        // Also check for any active entitlement at all
        let hasAnyActiveEntitlement = !customerInfo.entitlements.active.isEmpty
        
        isSubscriptionActive = proEntitlement || premiumEntitlement || cashmonkiProEntitlement || cashmonkiEntitlement || hasAnyActiveEntitlement
        
        print("💰 RevenueCat: Entitlement status check:")
        print("   🎯 'Pro' entitlement: \(proEntitlement)")
        print("   ✨ 'premium' entitlement: \(premiumEntitlement)")
        print("   💎 'Cashmonki Pro' entitlement: \(cashmonkiProEntitlement)")
        print("   🐒 'Cashmonki' entitlement: \(cashmonkiEntitlement)")
        print("   🔥 Any active entitlement: \(hasAnyActiveEntitlement)")
        print("   📱 Final subscription active: \(isSubscriptionActive)")
        
        // Debug: Show all available entitlements
        print("🔍 RevenueCat: All entitlements:")
        for (identifier, entitlement) in customerInfo.entitlements.all {
            print("   📋 '\(identifier)': active=\(entitlement.isActive), expires=\(entitlement.expirationDate?.description ?? "never")")
        }
        
        // Debug: Show active entitlements specifically
        print("🔥 RevenueCat: Active entitlements:")
        if customerInfo.entitlements.active.isEmpty {
            print("   ❌ No active entitlements found")
        } else {
            for (identifier, entitlement) in customerInfo.entitlements.active {
                print("   ✅ '\(identifier)': expires=\(entitlement.expirationDate?.description ?? "never")")
            }
        }
        
        print("🔍 RevenueCat: ======= STATUS UPDATE COMPLETE =======")
    }
    
    /// Force refresh customer info from RevenueCat (useful for debugging)
    func forceRefreshCustomerInfo() async {
        print("🔄 RevenueCat: Force refreshing customer info...")
        await loadCustomerInfo()
    }
    
    // MARK: - Offerings
    
    func loadOfferings() async {
        print("💰 RevenueCat: Loading offerings...")
        
        // CRITICAL FIX: Ensure RevenueCat is configured before accessing Purchases.shared
        guard isConfigured else {
            print("❌ RevenueCat: Cannot load offerings - RevenueCat not configured")
            return
        }
        
        do {
            let offerings = try await Purchases.shared.offerings()
            await MainActor.run {
                self.offerings = offerings
                print("✅ RevenueCat: Loaded \(offerings.all.count) total offerings")
                
                // Check if our specific offering exists
                if let specificOffering = offerings.offering(identifier: self.offeringID) {
                    print("✅ RevenueCat: Found specific offering '\(self.offeringID)' with \(specificOffering.availablePackages.count) packages")
                    for package in specificOffering.availablePackages {
                        print("   📦 Package: \(package.storeProduct.localizedTitle) - \(package.storeProduct.localizedPriceString)")
                    }
                } else {
                    print("⚠️ RevenueCat: Specific offering '\(self.offeringID)' not found")
                    print("📋 Available offerings: \(offerings.all.keys.joined(separator: ", "))")
                    
                    // If we have a current offering, mention it
                    if let currentOffering = offerings.current {
                        print("🎯 RevenueCat: Current offering available: '\(currentOffering.identifier)' with \(currentOffering.availablePackages.count) packages")
                    }
                }
            }
        } catch {
            await MainActor.run {
                print("❌ RevenueCat: Failed to load offerings: \(error.localizedDescription)")
                print("🔍 RevenueCat: Error details: \(error)")
                
                // Provide helpful setup guidance
                if error.localizedDescription.contains("configuration") {
                    print("💡 RevenueCat: SETUP REQUIRED - Complete Configuration Checklist:")
                    print("   📋 1. ENTITLEMENTS: Create entitlement 'pro' in RevenueCat dashboard")
                    print("   📦 2. PRODUCTS: Add products 'cashmonki_pro_monthly', 'cashmonki_pro_yearly'") 
                    print("   🔗 3. ATTACH: Link both products to the 'pro' entitlement")
                    print("   🎯 4. OFFERINGS: Create offerings and add products to them")
                    print("   ✅ 5. VERIFY: Products must match StoreKit Configuration File")
                    print("   📱 Current StoreKit products: cashmonki_pro_monthly, cashmonki_pro_yearly")
                    print("🧪 RevenueCat: DEBUG MODE - Premium features enabled for testing")
                }
            }
        }
    }
    
    // MARK: - Paywall Presentation
    
    func presentPaywall() async {
        print("🎯 RevenueCat: ======== PRESENT PAYWALL REQUESTED ========")
        print("💰 RevenueCat: Triggering native PaywallView presentation...")
        
        // Check if RevenueCat is properly configured
        guard let apiKey = Config.revenueCatAPIKey, !apiKey.contains("YOUR_REVENUECAT_API_KEY_HERE") else {
            print("❌ RevenueCat: Cannot present paywall - no valid API key configured")
            print("💡 RevenueCat: Add RevenueCat API key to Info.plist")
            
            #if DEBUG
            print("🧪 RevenueCat: DEBUG MODE - Presenting StoreKit test paywall")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowRevenueCatError"), 
                    object: "Premium features require RevenueCat API key. In production, this would show the subscription paywall."
                )
            }
            #else
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowRevenueCatError"), 
                    object: "RevenueCat not configured. Please add API key."
                )
            }
            #endif
            return
        }
        
        // Ensure offerings are loaded before presenting paywall
        print("🔍 RevenueCat: Checking offerings state...")
        print("💰 RevenueCat: offerings == nil: \(offerings == nil)")
        
        if offerings == nil {
            print("🔄 RevenueCat: No cached offerings, loading from server first...")
            await loadOfferings()
        }
        
        // Verify we have valid offerings before proceeding
        await MainActor.run {
            if let targetOffering = self.targetOffering {
                print("✅ RevenueCat: Valid target offering found, presenting paywall")
                print("🎯 RevenueCat: Offering ID: \(targetOffering.identifier)")
                print("📦 RevenueCat: Available packages: \(targetOffering.availablePackages.count)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("PresentNativePaywall"), 
                    object: targetOffering.identifier
                )
            } else {
                print("❌ RevenueCat: No valid offering available for paywall")
                print("💡 RevenueCat: Check RevenueCat dashboard configuration")
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowRevenueCatError"), 
                    object: "No subscription plans available. Please try again later."
                )
            }
        }
    }
    
    // MARK: - Purchasing
    
    func purchase(package: Package) async -> (success: Bool, error: Error?) {
        print("💳 === REVENUECAT PURCHASE DEBUG START ===")
        print("💳 RevenueCat: Starting purchase for \(package.storeProduct.localizedTitle)")
        print("💳 Package ID: \(package.storeProduct.productIdentifier)")
        print("💳 Package Type: \(package.packageType)")
        print("💳 Package Price: \(package.storeProduct.localizedPriceString)")
        print("💳 Current customer info before purchase: \(customerInfo?.description ?? "nil")")
        print("💳 Current subscription status: \(isSubscriptionActive)")
        
        // CRITICAL FIX: Ensure RevenueCat is configured before accessing Purchases.shared
        guard isConfigured else {
            print("❌ RevenueCat: Cannot purchase - RevenueCat not configured")
            return (false, NSError(domain: "RevenueCat", code: -1, userInfo: [NSLocalizedDescriptionKey: "RevenueCat not configured"]))
        }
        
        do {
            print("💳 RevenueCat: Calling Purchases.shared.purchase()...")
            let result = try await Purchases.shared.purchase(package: package)
            print("💳 RevenueCat: Purchase call completed successfully")
            print("💳 Purchase result - userCancelled: \(result.userCancelled)")
            print("💳 Purchase result - customerInfo: \(result.customerInfo.description)")
            
            await MainActor.run {
                if !result.userCancelled {
                    print("💳 RevenueCat: Processing successful purchase...")
                    self.customerInfo = result.customerInfo
                    self.updateSubscriptionStatus(result.customerInfo)
                    print("✅ RevenueCat: Purchase successful - subscription updated")
                    print("✅ New subscription status: \(self.isSubscriptionActive)")
                } else {
                    print("⏹️ RevenueCat: Purchase cancelled by user")
                }
            }
            
            let success = !result.userCancelled
            print("💳 RevenueCat: Returning success: \(success), error: nil")
            print("💳 === REVENUECAT PURCHASE DEBUG END ===")
            return (success: success, error: nil)
        } catch {
            print("❌ === REVENUECAT PURCHASE ERROR ===")
            print("❌ RevenueCat: Purchase threw exception")
            print("❌ Error: \(error)")
            print("❌ Error description: \(error.localizedDescription)")
            
            let nsError = error as NSError
            print("❌ NSError domain: \(nsError.domain)")
            print("❌ NSError code: \(nsError.code)")
            print("❌ NSError userInfo: \(nsError.userInfo)")
            
            // Check for common purchase errors
            if nsError.domain == "SKErrorDomain" {
                print("❌ StoreKit error detected in RevenueCatManager")
                if nsError.code == 2 {
                    print("❌ User cancelled purchase in StoreKit")
                }
            }
            
            await MainActor.run {
                print("❌ RevenueCat: Purchase failed on main actor: \(error.localizedDescription)")
            }
            
            print("❌ RevenueCat: Returning success: false, error: \(error)")
            print("❌ === REVENUECAT PURCHASE ERROR END ===")
            return (success: false, error: error)
        }
    }
    
    // Legacy completion-based version for backwards compatibility
    func purchase(package: Package, completion: @escaping (Bool, Error?) -> Void) {
        Task {
            let result = await purchase(package: package)
            await MainActor.run {
                completion(result.success, result.error)
            }
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async -> (success: Bool, error: Error?) {
        print("🔄 RevenueCat: Restoring purchases...")
        
        // CRITICAL FIX: Ensure RevenueCat is configured before accessing Purchases.shared
        guard isConfigured else {
            print("❌ RevenueCat: Cannot restore purchases - RevenueCat not configured")
            return (false, NSError(domain: "RevenueCat", code: -1, userInfo: [NSLocalizedDescriptionKey: "RevenueCat not configured"]))
        }
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await MainActor.run {
                self.customerInfo = customerInfo
                self.updateSubscriptionStatus(customerInfo)
                print("✅ RevenueCat: Purchases restored successfully")
            }
            return (success: true, error: nil)
        } catch {
            await MainActor.run {
                print("❌ RevenueCat: Failed to restore purchases: \(error.localizedDescription)")
            }
            return (success: false, error: error)
        }
    }
    
    // Legacy completion-based version for backwards compatibility
    func restorePurchases(completion: @escaping (Bool, Error?) -> Void) {
        Task {
            let result = await restorePurchases()
            await MainActor.run {
                completion(result.success, result.error)
            }
        }
    }
    
    // MARK: - User Identity
    
    func identifyUser(userId: String) async {
        print("👤 RevenueCat: Identifying user: \(userId.prefix(8))...")
        
        // CRITICAL FIX: Ensure RevenueCat is configured before accessing Purchases.shared
        guard isConfigured else {
            print("❌ RevenueCat: Cannot identify user - RevenueCat not configured")
            print("🔧 RevenueCat: Call configure() first before identifying users")
            return
        }
        
        do {
            let result = try await Purchases.shared.logIn(userId)
            await MainActor.run {
                self.customerInfo = result.customerInfo
                self.updateSubscriptionStatus(result.customerInfo)
                print("✅ RevenueCat: User identified successfully - created: \(result.created)")
            }
        } catch {
            await MainActor.run {
                print("❌ RevenueCat: Failed to identify user: \(error.localizedDescription)")
            }
        }
    }
    
    func logoutUser() async {
        print("👋 RevenueCat: Logging out user...")
        
        // CRITICAL FIX: Ensure RevenueCat is configured before accessing Purchases.shared
        guard isConfigured else {
            print("❌ RevenueCat: Cannot logout user - RevenueCat not configured")
            return
        }
        
        do {
            let customerInfo = try await Purchases.shared.logOut()
            await MainActor.run {
                self.customerInfo = customerInfo
                self.updateSubscriptionStatus(customerInfo)
                print("✅ RevenueCat: User logged out successfully")
            }
        } catch {
            await MainActor.run {
                print("❌ RevenueCat: Failed to logout: \(error.localizedDescription)")
            }
        }
    }
    
    // Legacy completion-based versions for backwards compatibility
    func identifyUser(userId: String, completion: ((Bool) -> Void)? = nil) {
        Task {
            await identifyUser(userId: userId)
            await MainActor.run {
                completion?(true)
            }
        }
    }
    
    func logoutUser(completion: ((Bool) -> Void)? = nil) {
        Task {
            await logoutUser()
            await MainActor.run {
                completion?(true)
            }
        }
    }
    
    // MARK: - Premium Features Helper
    
    func hasFeature(_ feature: PremiumFeature) -> Bool {
        #if DEBUG
        // For testing without RevenueCat dashboard setup
        if debugTestProEnabled {
            return true
        }
        #endif
        
        switch feature {
        case .unlimitedTransactions:
            return isSubscriptionActive
        case .advancedAnalytics:
            return isSubscriptionActive
        case .cloudSync:
            return isSubscriptionActive
        case .exportData:
            return isSubscriptionActive
        case .customCategories:
            return isSubscriptionActive
        }
    }
    
    // MARK: - Development Testing
    
    #if DEBUG
    /// For testing purposes only - simulates premium subscription
    func enableTestPremium() {
        print("🧪 RevenueCat: Enabling test premium features")
        isSubscriptionActive = true
    }
    
    /// For testing purposes only - disables premium subscription
    func disableTestPremium() {
        print("🧪 RevenueCat: Disabling test premium features")
        isSubscriptionActive = false
    }
    #endif
    
    // MARK: - Paywall State Management
    
    /// Get the specific offering for paywall presentation using smart detection
    var targetOffering: Offering? {
        print("🔍 RevenueCat: targetOffering requested")
        print("💰 RevenueCat: offerings nil check: \(offerings == nil ? "NIL" : "EXISTS")")
        
        guard let offerings = offerings else {
            print("❌ RevenueCat: No offerings loaded - call loadOfferings() first")
            return nil
        }
        
        print("💰 RevenueCat: Total offerings count: \(offerings.all.count)")
        print("📋 RevenueCat: Available offering IDs: \(offerings.all.keys.joined(separator: ", "))")
        print("🔍 RevenueCat: Looking for offering using smart detection...")
        
        // Use smart detection to find the best offering
        if let smartID = smartOfferingID,
           let smartOffering = offerings.offering(identifier: smartID) {
            print("✅ RevenueCat: Smart detection found offering '\(smartID)'")
            print("📦 RevenueCat: Offering has \(smartOffering.availablePackages.count) packages")
            for package in smartOffering.availablePackages {
                print("   📦 Package: \(package.storeProduct.localizedTitle) - \(package.storeProduct.localizedPriceString)")
            }
            return smartOffering
        }
        
        // Legacy fallback: try hardcoded offering ID
        if let specificOffering = offerings.offering(identifier: offeringID) {
            print("✅ RevenueCat: Found legacy offering '\(offeringID)'")
            print("📦 RevenueCat: Offering has \(specificOffering.availablePackages.count) packages")
            for package in specificOffering.availablePackages {
                print("   📦 Package: \(package.storeProduct.localizedTitle) - \(package.storeProduct.localizedPriceString)")
            }
            return specificOffering
        }
        
        // Try case variations of Cashmonki offering
        let caseVariations = ["cashmonki", "CASHMONKI", "CashMonki", "cashMonki"]
        for variation in caseVariations {
            if let offering = offerings.offering(identifier: variation) {
                print("✅ RevenueCat: Found offering with case variation '\(variation)'")
                print("📦 RevenueCat: Offering has \(offering.availablePackages.count) packages")
                return offering
            }
        }
        
        // Try the yearly offering as fallback
        if let yearlyOffering = offerings.offering(identifier: "cashmonki_pro_yearly") {
            print("✅ RevenueCat: Found yearly offering as fallback")
            print("📦 RevenueCat: Yearly offering has \(yearlyOffering.availablePackages.count) packages")
            return yearlyOffering
        }
        
        // Try any offering that contains "cash" in the name
        for (identifier, offering) in offerings.all {
            if identifier.lowercased().contains("cash") {
                print("✅ RevenueCat: Found cash-related offering: '\(identifier)'")
                print("📦 RevenueCat: Offering has \(offering.availablePackages.count) packages")
                return offering
            }
        }
        
        // Fallback to current offering
        if let currentOffering = offerings.current {
            print("🎯 RevenueCat: Specific offering not found, using current: '\(currentOffering.identifier)'")
            print("📦 RevenueCat: Current offering has \(currentOffering.availablePackages.count) packages")
            for package in currentOffering.availablePackages {
                print("   📦 Package: \(package.storeProduct.localizedTitle) - \(package.storeProduct.localizedPriceString)")
            }
            return currentOffering
        }
        
        // Last resort: Use the first available offering
        if let firstOffering = offerings.all.first?.value {
            print("🎯 RevenueCat: Using first available offering: '\(firstOffering.identifier)'")
            print("📦 RevenueCat: Offering has \(firstOffering.availablePackages.count) packages")
            return firstOffering
        }
        
        // No offerings found at all
        print("❌ RevenueCat: No offerings available - neither specific nor current")
        print("💡 RevenueCat: Configuration Help:")
        print("   - Ensure products are created in App Store Connect")
        print("   - Verify offering exists in RevenueCat dashboard")
        print("   - For testing: Use StoreKit Configuration File in Xcode")
        print("   - Check that RevenueCat API key is valid")
        
        return nil
    }
}

// MARK: - PurchasesDelegate

#if canImport(RevenueCat)
extension RevenueCatManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.updateSubscriptionStatus(customerInfo)
            print("🔄 RevenueCat: Customer info updated")
        }
    }
    
    nonisolated func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase startPurchase: @escaping StartPurchaseBlock) {
        // Handle promoted purchases from App Store
        startPurchase { [weak self] transaction, customerInfo, error, userCancelled in
            if let customerInfo = customerInfo {
                Task { @MainActor in
                    self?.customerInfo = customerInfo
                    self?.updateSubscriptionStatus(customerInfo)
                    print("✅ RevenueCat: Promoted purchase successful")
                }
            }
        }
    }
}
#endif

#else
// MARK: - Fallback Implementation (when RevenueCat is not available)

class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var customerInfo: Any? = nil
    @Published var offerings: Any? = nil
    @Published var isSubscriptionActive: Bool = false
    
    /// Convenience property to check if user has Pro subscription
    var isProUser: Bool {
        return isSubscriptionActive
    }
    
    override private init() {}
    
    func configure() {
        print("❌ RevenueCat: Not available - using fallback implementation")
    }
    
    func loadCustomerInfo() {
        print("❌ RevenueCat: Not available - cannot load customer info")
    }
    
    func loadOfferings() {
        print("❌ RevenueCat: Not available - cannot load offerings")
    }
    
    func purchase(package: Any, completion: @escaping (Bool, Error?) -> Void) {
        print("❌ RevenueCat: Not available - cannot purchase")
        completion(false, nil)
    }
    
    func restorePurchases(completion: @escaping (Bool, Error?) -> Void) {
        print("❌ RevenueCat: Not available - cannot restore purchases")
        completion(false, nil)
    }
    
    func identifyUser(userId: String) {
        print("❌ RevenueCat: Not available - cannot identify user")
    }
    
    func logoutUser() {
        print("❌ RevenueCat: Not available - cannot logout user")
    }
    
    func hasFeature(_ feature: PremiumFeature) -> Bool {
        // In fallback mode, return false for all premium features
        return false
    }
}

#endif

// MARK: - Premium Features Enum

enum PremiumFeature {
    case unlimitedTransactions
    case advancedAnalytics
    case cloudSync
    case exportData
    case customCategories
}
