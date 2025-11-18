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
class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isSubscriptionActive: Bool = false
    
    // Your specific offering ID from RevenueCat dashboard
    private let offeringID = "ofrngc3bcf38400"
    
    override private init() {}
    
    // MARK: - Configuration
    
    func configure() {
        // Get RevenueCat API key from secure storage
        guard let apiKey = Config.revenueCatAPIKey else {
            print("❌ RevenueCat: No API key found in secure storage")
            return
        }
        
        print("✅ RevenueCat: Configuring with API key from secure storage")
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)
        
        // Set up delegate (must be set after configure)
        Purchases.shared.delegate = self
        
        // Load initial customer info
        loadCustomerInfo()
        loadOfferings()
    }
    
    // MARK: - Customer Info
    
    func loadCustomerInfo() {
        Purchases.shared.getCustomerInfo { [weak self] customerInfo, error in
            DispatchQueue.main.async {
                if let customerInfo = customerInfo {
                    self?.customerInfo = customerInfo
                    self?.updateSubscriptionStatus(customerInfo)
                } else if let error = error {
                    print("❌ RevenueCat: Failed to load customer info: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateSubscriptionStatus(_ customerInfo: CustomerInfo) {
        // Check if user has any active entitlements
        // You'll need to define your entitlement identifier in RevenueCat dashboard
        isSubscriptionActive = customerInfo.entitlements["premium"]?.isActive == true
        
        print("💰 RevenueCat: Subscription active: \(isSubscriptionActive)")
    }
    
    // MARK: - Offerings
    
    func loadOfferings() {
        print("💰 RevenueCat: Loading offerings...")
        Purchases.shared.getOfferings { [weak self] offerings, error in
            DispatchQueue.main.async {
                if let offerings = offerings {
                    self?.offerings = offerings
                    print("✅ RevenueCat: Loaded \(offerings.all.count) total offerings")
                    
                    // Check if our specific offering exists
                    if let specificOffering = offerings.offering(identifier: self?.offeringID ?? "") {
                        print("✅ RevenueCat: Found specific offering '\(self?.offeringID ?? "")' with \(specificOffering.availablePackages.count) packages")
                        for package in specificOffering.availablePackages {
                            print("   📦 Package: \(package.storeProduct.localizedTitle) - \(package.storeProduct.localizedPriceString)")
                        }
                    } else {
                        print("⚠️ RevenueCat: Specific offering '\(self?.offeringID ?? "")' not found")
                        print("📋 Available offerings: \(offerings.all.keys.joined(separator: ", "))")
                    }
                } else if let error = error {
                    print("❌ RevenueCat: Failed to load offerings: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Paywall Presentation
    
    func presentPaywall() {
        print("💰 RevenueCat: Triggering native PaywallView presentation...")
        
        DispatchQueue.main.async { [weak self] in
            // First load offerings to ensure they're available
            self?.loadOfferings()
            
            // Post notification for SwiftUI to present RevenueCat's native PaywallView
            NotificationCenter.default.post(
                name: NSNotification.Name("PresentNativePaywall"), 
                object: self?.offeringID
            )
            print("✅ RevenueCat: Posted native paywall presentation notification")
        }
    }
    
    // MARK: - Purchasing
    
    func purchase(package: Package, completion: @escaping (Bool, Error?) -> Void) {
        Purchases.shared.purchase(package: package) { [weak self] transaction, customerInfo, error, userCancelled in
            DispatchQueue.main.async {
                if let customerInfo = customerInfo {
                    self?.customerInfo = customerInfo
                    self?.updateSubscriptionStatus(customerInfo)
                    completion(true, nil)
                    print("✅ RevenueCat: Purchase successful")
                } else if userCancelled {
                    completion(false, nil)
                    print("⏹️ RevenueCat: Purchase cancelled by user")
                } else if let error = error {
                    completion(false, error)
                    print("❌ RevenueCat: Purchase failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases(completion: @escaping (Bool, Error?) -> Void) {
        Purchases.shared.restorePurchases { [weak self] customerInfo, error in
            DispatchQueue.main.async {
                if let customerInfo = customerInfo {
                    self?.customerInfo = customerInfo
                    self?.updateSubscriptionStatus(customerInfo)
                    completion(true, nil)
                    print("✅ RevenueCat: Purchases restored")
                } else if let error = error {
                    completion(false, error)
                    print("❌ RevenueCat: Failed to restore purchases: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - User Identity
    
    func identifyUser(userId: String) {
        Purchases.shared.logIn(userId) { [weak self] customerInfo, created, error in
            DispatchQueue.main.async {
                if let customerInfo = customerInfo {
                    self?.customerInfo = customerInfo
                    self?.updateSubscriptionStatus(customerInfo)
                    print("👤 RevenueCat: User identified - created: \(created)")
                } else if let error = error {
                    print("❌ RevenueCat: Failed to identify user: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func logoutUser() {
        Purchases.shared.logOut { [weak self] customerInfo, error in
            DispatchQueue.main.async {
                if let customerInfo = customerInfo {
                    self?.customerInfo = customerInfo
                    self?.updateSubscriptionStatus(customerInfo)
                    print("👋 RevenueCat: User logged out")
                } else if let error = error {
                    print("❌ RevenueCat: Failed to logout: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Premium Features Helper
    
    func hasFeature(_ feature: PremiumFeature) -> Bool {
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
    
    // MARK: - Paywall State Management
    
    /// Get the specific offering for paywall presentation
    var targetOffering: Offering? {
        return offerings?.offering(identifier: offeringID) ?? offerings?.current
    }
}

// MARK: - PurchasesDelegate

#if canImport(RevenueCat)
extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        DispatchQueue.main.async {
            self.customerInfo = customerInfo
            self.updateSubscriptionStatus(customerInfo)
            print("🔄 RevenueCat: Customer info updated")
        }
    }
    
    func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase startPurchase: @escaping StartPurchaseBlock) {
        // Handle promoted purchases from App Store
        startPurchase { [weak self] transaction, customerInfo, error, userCancelled in
            DispatchQueue.main.async {
                if let customerInfo = customerInfo {
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