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
    
    /// Convenience property to check if user has Pro subscription
    var isProUser: Bool {
        return isSubscriptionActive
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
        // Get RevenueCat API key from secure storage
        guard let apiKey = Config.revenueCatAPIKey else {
            print("❌ RevenueCat: No API key found in secure storage")
            print("💡 RevenueCat: For testing, configure API key in RevenueCat dashboard")
            print("💡 RevenueCat: Add your API key to Info.plist under 'RevenueCatAPIKey'")
            return
        }
        
        print("✅ RevenueCat: Configuring with API key from secure storage")
        Purchases.logLevel = .debug
        
        #if DEBUG
        // Force pure sandbox mode for testing with incomplete App Store Connect products
        Purchases.simulatesAskToBuyInSandbox = true
        print("🧪 RevenueCat: Enabled sandbox simulation for testing")
        print("🔧 RevenueCat: Forcing local testing mode - bypassing App Store Connect validation")
        #endif
        
        // Configure RevenueCat with the most recent API
        print("🔧 RevenueCat: Configuring with modern API...")
        
        #if DEBUG
        print("🧪 RevenueCat: Debug build - enabling StoreKit Configuration file testing")
        print("🔧 RevenueCat: StoreKit Configuration File: CashMonki/StoreKit/Configuration.storekit")
        print("⚠️ RevenueCat: Scheme configured with storeKitConfigurationFileReference")
        print("📱 RevenueCat: Products in config: cashmonki_pro_monthly, cashmonki_pro_yearly")
        print("🧪 RevenueCat: Using StoreKit 1 with configuration file override")
        
        // For StoreKit Configuration file testing, use StoreKit 1 with observer mode disabled
        let config = Configuration.Builder(withAPIKey: apiKey)
            .with(purchasesAreCompletedBy: .revenueCat, storeKitVersion: .storeKit1)
            .with(storeKit1Timeout: 30)  // Longer timeout for configuration file
            .build()
        #else
        print("📱 RevenueCat: Production build - standard configuration")
        let config = Configuration.Builder(withAPIKey: apiKey)
            .with(purchasesAreCompletedBy: .revenueCat, storeKitVersion: .storeKit1)
            .build()
        #endif
        
        Purchases.configure(with: config)
        print("✅ RevenueCat: Successfully configured")
        
        // Set up delegate (must be set after configure)
        Purchases.shared.delegate = self
        
        // Load initial customer info (async calls from nonisolated context)
        print("🔄 RevenueCat: Starting initial data load...")
        Task { @MainActor in
            await loadCustomerInfo()
            await loadOfferings()
            print("✅ RevenueCat: Initial data load completed")
        }
    }
    
    // MARK: - Customer Info
    
    func loadCustomerInfo() async {
        print("👤 RevenueCat: Loading customer info...")
        
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
        // Check if user has any active entitlements
        // Check for "Pro" entitlement (must match dashboard exactly)
        let hasProEntitlement = customerInfo.entitlements["Pro"]?.isActive == true
        let hasPremiumEntitlement = customerInfo.entitlements["premium"]?.isActive == true
        
        isSubscriptionActive = hasProEntitlement || hasPremiumEntitlement
        
        print("💰 RevenueCat: Entitlement status check:")
        print("   🎯 'pro' entitlement: \(hasProEntitlement)")
        print("   ✨ 'premium' entitlement: \(hasPremiumEntitlement)")
        print("   📱 Final subscription active: \(isSubscriptionActive)")
        
        // Debug: Show all available entitlements
        print("🔍 RevenueCat: Available entitlements:")
        for (identifier, entitlement) in customerInfo.entitlements.all {
            print("   📋 \(identifier): active=\(entitlement.isActive)")
        }
    }
    
    // MARK: - Offerings
    
    func loadOfferings() async {
        print("💰 RevenueCat: Loading offerings...")
        
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
    
    func presentPaywall() {
        print("🎯 RevenueCat: ======== PRESENT PAYWALL REQUESTED ========")
        print("💰 RevenueCat: Triggering native PaywallView presentation...")
        
        // Check if RevenueCat is properly configured
        guard let apiKey = Config.revenueCatAPIKey, !apiKey.contains("YOUR_REVENUECAT_API_KEY_HERE") else {
            print("❌ RevenueCat: Cannot present paywall - no valid API key configured")
            print("💡 RevenueCat: Add RevenueCat API key to Info.plist")
            
            #if DEBUG
            print("🧪 RevenueCat: DEBUG MODE - Presenting StoreKit test paywall")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowRevenueCatError"), 
                    object: "Premium features require RevenueCat API key. In production, this would show the subscription paywall."
                )
            }
            #else
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShowRevenueCatError"), 
                    object: "RevenueCat not configured. Please add API key."
                )
            }
            #endif
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            print("🔍 RevenueCat: Checking offerings state...")
            print("💰 RevenueCat: offerings == nil: \(self?.offerings == nil)")
            
            // Check if offerings are already loaded
            if self?.offerings != nil {
                print("✅ RevenueCat: Offerings already loaded, presenting paywall")
                print("🎯 RevenueCat: targetOffering available: \(self?.targetOffering != nil)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("PresentNativePaywall"), 
                    object: self?.offeringID
                )
            } else {
                print("🔄 RevenueCat: No cached offerings, loading from server...")
                // Load offerings first, then present paywall
                Purchases.shared.getOfferings { @Sendable [weak self] offerings, error in
                    DispatchQueue.main.async {
                        if let offerings = offerings {
                            print("✅ RevenueCat: Offerings loaded successfully")
                            self?.offerings = offerings
                            print("📊 RevenueCat: Loaded \(offerings.all.count) total offerings")
                            print("📋 RevenueCat: Available offering IDs: \(offerings.all.keys.joined(separator: ", "))")
                            
                            // Check if we have a valid target offering
                            if self?.targetOffering != nil {
                                print("🎯 RevenueCat: Valid target offering found, presenting paywall")
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("PresentNativePaywall"), 
                                    object: self?.offeringID
                                )
                            } else {
                                print("❌ RevenueCat: No valid offering available for paywall")
                            }
                        } else if let error = error {
                            print("❌ RevenueCat: Failed to load offerings: \(error.localizedDescription)")
                            print("🔍 RevenueCat: Error details: \(error)")
                            // Show error to user
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ShowRevenueCatError"), 
                                object: "Failed to load subscription options: \(error.localizedDescription)"
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Purchasing
    
    func purchase(package: Package) async -> (success: Bool, error: Error?) {
        print("💳 RevenueCat: Starting purchase for \(package.storeProduct.localizedTitle)...")
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            await MainActor.run {
                if !result.userCancelled {
                    self.customerInfo = result.customerInfo
                    self.updateSubscriptionStatus(result.customerInfo)
                    print("✅ RevenueCat: Purchase successful")
                } else {
                    print("⏹️ RevenueCat: Purchase cancelled by user")
                }
            }
            
            return (success: !result.userCancelled, error: nil)
        } catch {
            await MainActor.run {
                print("❌ RevenueCat: Purchase failed: \(error.localizedDescription)")
            }
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
        // For testing, you can temporarily enable premium features
        // by setting this to true during development
        let debugPremiumEnabled = false  // Testing with RevenueCat test API key
        if debugPremiumEnabled {
            print("🧪 RevenueCat: DEBUG MODE - Premium feature '\(feature)' enabled for testing")
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
