//
//  CurrencyPreferences.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import Foundation
import Combine

/// Centralized currency preference system for the entire app
/// All currency-related displays should reference this singleton
final class CurrencyPreferences: ObservableObject {
    static let shared = CurrencyPreferences()
    
    @Published var primaryCurrency: Currency = .php // Default fallback, will be overridden by loadFromStorage() or onboarding
    @Published var secondaryCurrency: Currency? = nil
    
    private let userDefaults = UserDefaults.standard
    private let primaryCurrencyKey = "userPrimaryCurrency"
    private let secondaryCurrencyKey = "userSecondaryCurrency"
    
    private init() {
        loadFromStorage()
        print("💰 CurrencyPreferences: Initialized with primary: \(primaryCurrency.rawValue), secondary: \(secondaryCurrency?.rawValue ?? "none")")
    }
    
    // MARK: - Currency Symbol Access
    
    /// Get the primary currency symbol (₱, $, £, etc.)
    var primarySymbol: String {
        return primaryCurrency.symbol
    }
    
    /// Get the secondary currency symbol (₱, $, £, etc.)
    var secondarySymbol: String {
        return secondaryCurrency?.symbol ?? "$"
    }
    
    /// Format amount with primary currency symbol
    func formatPrimaryAmount(_ amount: Double) -> String {
        return "\(primarySymbol)\(formatCurrency(amount))"
    }
    
    /// Format amount with secondary currency symbol
    func formatSecondaryAmount(_ amount: Double) -> String {
        return "\(secondarySymbol)\(formatCurrency(amount))"
    }
    
    /// Format amount with specified currency
    func formatAmount(_ amount: Double, currency: Currency) -> String {
        return "\(currency.symbol)\(formatCurrency(amount))"
    }
    
    // MARK: - Currency Updates
    
    /// Update primary currency and persist to storage
    func setPrimaryCurrency(_ currency: Currency) {
        print("🔍 CURRENCY DEBUG: 📝 CurrencyPreferences.setPrimaryCurrency called")
        print("🔍 CURRENCY DEBUG: Old primary: \(primaryCurrency.rawValue)")
        print("🔍 CURRENCY DEBUG: New primary: \(currency.rawValue)")
        primaryCurrency = currency
        saveToStorage()
        
        // Also sync with UserManager if available
        syncWithUserManager()
        print("🔍 CURRENCY DEBUG: ✅ Primary currency updated and saved")
    }
    
    /// Update secondary currency and persist to storage
    func setSecondaryCurrency(_ currency: Currency?) {
        print("💰 CurrencyPreferences: Updating secondary currency from \(secondaryCurrency?.rawValue ?? "none") to \(currency?.rawValue ?? "none")")
        secondaryCurrency = currency
        saveToStorage()
    }
    
    /// Initialize from user's account data
    func initializeFromUserAccount() {
        let userManager = UserManager.shared
        
        // Get primary currency from user's default account
        if let defaultAccount = userManager.currentUser.accounts.first(where: { $0.isDefault }) {
            let accountCurrency = defaultAccount.currency
            if accountCurrency != primaryCurrency {
                print("💰 CurrencyPreferences: Syncing primary currency from user account: \(accountCurrency.rawValue)")
                primaryCurrency = accountCurrency
                saveToStorage()
            }
        } else if let firstAccount = userManager.currentUser.accounts.first {
            let accountCurrency = firstAccount.currency
            if accountCurrency != primaryCurrency {
                print("💰 CurrencyPreferences: Syncing primary currency from first account: \(accountCurrency.rawValue)")
                primaryCurrency = accountCurrency
                saveToStorage()
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadFromStorage() {
        // Load primary currency
        if let primaryRaw = userDefaults.string(forKey: primaryCurrencyKey),
           let currency = Currency(rawValue: primaryRaw) {
            primaryCurrency = currency
            print("💰 CurrencyPreferences: Loaded primary currency from storage: \(currency.rawValue)")
        } else {
            print("💰 CurrencyPreferences: No stored primary currency, using default: \(primaryCurrency.rawValue)")
        }
        
        // Load secondary currency
        if let secondaryRaw = userDefaults.string(forKey: secondaryCurrencyKey),
           let currency = Currency(rawValue: secondaryRaw) {
            secondaryCurrency = currency
            print("💰 CurrencyPreferences: Loaded secondary currency from storage: \(currency.rawValue)")
        } else {
            print("💰 CurrencyPreferences: No stored secondary currency, using default: \(secondaryCurrency?.rawValue ?? "none")")
        }
    }
    
    private func saveToStorage() {
        userDefaults.set(primaryCurrency.rawValue, forKey: primaryCurrencyKey)
        
        if let secondary = secondaryCurrency {
            userDefaults.set(secondary.rawValue, forKey: secondaryCurrencyKey)
        } else {
            userDefaults.removeObject(forKey: secondaryCurrencyKey)
        }
        
        print("💰 CurrencyPreferences: Saved to storage - Primary: \(primaryCurrency.rawValue), Secondary: \(secondaryCurrency?.rawValue ?? "none")")
    }
    
    private func syncWithUserManager() {
        // Update UserManager's primary currency when our preference changes
        UserManager.shared.updatePrimaryCurrency(primaryCurrency)
    }
    
    // MARK: - Helper Functions
    
    /// Format currency amount with smart decimal handling
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0  // Hide .00
        formatter.maximumFractionDigits = 2  // Show up to .01
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
    
    // MARK: - Debug Methods
    
    func debugCurrentSettings() {
        print("🔍 CurrencyPreferences: Current settings:")
        print("   💰 Primary: \(primaryCurrency.rawValue) (\(primaryCurrency.displayName)) - Symbol: \(primarySymbol)")
        print("   💱 Secondary: \(secondaryCurrency?.rawValue ?? "none") (\(secondaryCurrency?.displayName ?? "none")) - Symbol: \(secondarySymbol)")
        print("   📱 Example formatting: \(formatPrimaryAmount(1234.56))")
    }
    
    /// Reset all currency preferences to fresh state (for account deletion)
    func resetToDefault() {
        print("🔄 CurrencyPreferences: Resetting to fresh state - new user will select currency during onboarding")
        
        // Reset to initial default (PHP - technical default to prevent crashes)
        primaryCurrency = .php
        secondaryCurrency = nil
        
        // CRITICAL: Clear ALL stored preferences and flags
        UserDefaults.standard.removeObject(forKey: "userPrimaryCurrency")
        UserDefaults.standard.removeObject(forKey: "userSecondaryCurrency")
        UserDefaults.standard.removeObject(forKey: "hasSetPrimaryCurrency")
        UserDefaults.standard.removeObject(forKey: "hasCompletedCurrencySelection")
        
        // Don't save to storage - let new user pick their currency
        // saveToStorage() is intentionally NOT called here
        
        // Trigger UI update
        objectWillChange.send()
        
        print("✅ CurrencyPreferences: Reset to fresh state - PHP technical default, no stored preferences")
        print("   New user will select their preferred currency during onboarding")
    }
}

// MARK: - Global Convenience Functions

/// Global function to format amount with user's primary currency
func formatWithPrimaryCurrency(_ amount: Double) -> String {
    return CurrencyPreferences.shared.formatPrimaryAmount(amount)
}

/// Global function to format amount with user's secondary currency
func formatWithSecondaryCurrency(_ amount: Double) -> String {
    return CurrencyPreferences.shared.formatSecondaryAmount(amount)
}

/// Global function to get user's primary currency symbol
func primaryCurrencySymbol() -> String {
    return CurrencyPreferences.shared.primarySymbol
}

/// Global function to get user's secondary currency symbol
func secondaryCurrencySymbol() -> String {
    return CurrencyPreferences.shared.secondarySymbol
}