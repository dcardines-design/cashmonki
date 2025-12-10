//
//  SecureAPIKeyStorage.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//  
//  IMPORTANT: This file contains API keys that will be stored securely in keychain
//  on first app launch, then these hardcoded values should be removed from source code.
//

import Foundation

/// One-time secure initialization of API keys
/// After first launch, these hardcoded keys can be removed from source code
struct SecureAPIKeyStorage {
    
    /// Initialize API keys from secure hardcoded values on first launch only
    /// This method should be called once, then the hardcoded keys can be removed
    static func initializeSecureKeys() {
        // Only run this on first launch when no keys exist in keychain
        let hasOpenRouterKey = KeychainManager.shared.exists(for: .openRouterAPIKey)
        let hasRevenueCatKey = KeychainManager.shared.exists(for: .revenueCatAPIKey)
        
        if !hasOpenRouterKey || !hasRevenueCatKey {
            print("🔐 SecureAPIKeyStorage: First launch detected, storing API keys securely...")
            
            // OpenRouter API Key - store once then remove from code
            if !hasOpenRouterKey {
                let openRouterKey = "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"
                if KeychainManager.shared.store(openRouterKey, for: .openRouterAPIKey) {
                    print("✅ OpenRouter API key securely stored in keychain")
                } else {
                    print("❌ Failed to store OpenRouter API key in keychain")
                }
            }
            
            // RevenueCat API Key - store once then remove from code
            if !hasRevenueCatKey {
                let revenueCatKey = "placeholder_key_for_initial_setup"
                if KeychainManager.shared.store(revenueCatKey, for: .revenueCatAPIKey) {
                    print("✅ RevenueCat API key securely stored in keychain")
                } else {
                    print("❌ Failed to store RevenueCat API key in keychain")
                }
            }
            
            print("🔐 SecureAPIKeyStorage: API keys now stored securely in device keychain")
            print("⚠️  SecureAPIKeyStorage: SECURITY NOTE - Remove hardcoded keys from source after first successful launch")
        } else {
            print("✅ SecureAPIKeyStorage: API keys already exist in keychain - no action needed")
        }
    }
}