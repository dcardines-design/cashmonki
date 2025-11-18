import Foundation

/// Configuration manager for app settings and API keys
struct Config {
    
    /// Get OpenRouter API key from most secure source available
    static var openRouterAPIKey: String? {
        // Priority 1: Check keychain (most secure)
        if let keychainKey = KeychainManager.shared.retrieve(for: .openRouterAPIKey) {
            return keychainKey
        }
        
        // Priority 2: Check environment variable (for development)
        if let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] {
            return envKey
        }
        
        // Priority 3: Check Info.plist (better than hardcoded)
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OpenRouterAPIKey") as? String,
           !plistKey.isEmpty && plistKey != "YOUR_API_KEY_HERE" {
            return plistKey
        }
        
        return nil
    }
    
    /// Get RevenueCat API key from most secure source available
    static var revenueCatAPIKey: String? {
        // Priority 1: Check keychain (most secure)
        if let keychainKey = KeychainManager.shared.retrieve(for: .revenueCatAPIKey) {
            return keychainKey
        }
        
        // Priority 2: Check environment variable (for development)
        if let envKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] {
            return envKey
        }
        
        // Priority 3: Check Info.plist (better than hardcoded)
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
           !plistKey.isEmpty && plistKey != "YOUR_REVENUECAT_API_KEY_HERE" {
            return plistKey
        }
        
        return nil
    }
    
    /// Initialize API keys on first app launch
    static func initializeAPIKeys() {
        initializeOpenRouterKey()
        initializeRevenueCatKey()
    }
    
    /// Initialize OpenRouter API key on first app launch
    static func initializeOpenRouterKey() {
        // Only store if not already in keychain
        guard !KeychainManager.shared.exists(for: .openRouterAPIKey) else { 
            print("✅ OpenRouter API key already exists in keychain")
            return 
        }
        
        // Try to get API key from environment or plist first
        if let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] {
            if KeychainManager.shared.store(envKey, for: .openRouterAPIKey) {
                print("✅ OpenRouter API key from environment stored in keychain")
            } else {
                print("❌ Failed to store OpenRouter API key from environment")
            }
        } else if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OpenRouterAPIKey") as? String,
                  !plistKey.isEmpty && plistKey != "YOUR_API_KEY_HERE" {
            if KeychainManager.shared.store(plistKey, for: .openRouterAPIKey) {
                print("✅ OpenRouter API key from Info.plist stored in keychain")
            } else {
                print("❌ Failed to store OpenRouter API key from Info.plist")
            }
        } else {
            print("⚠️ No OpenRouter API key found in environment or Info.plist")
        }
    }
    
    /// Initialize RevenueCat API key on first app launch
    static func initializeRevenueCatKey() {
        // Only store if not already in keychain
        guard !KeychainManager.shared.exists(for: .revenueCatAPIKey) else {
            print("✅ RevenueCat API key already exists in keychain")
            return
        }
        
        // Try to get API key from environment or plist first
        if let envKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] {
            if KeychainManager.shared.store(envKey, for: .revenueCatAPIKey) {
                print("✅ RevenueCat API key from environment stored in keychain")
            } else {
                print("❌ Failed to store RevenueCat API key from environment")
            }
        } else if let plistKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
                  !plistKey.isEmpty && plistKey != "YOUR_REVENUECAT_API_KEY_HERE" {
            if KeychainManager.shared.store(plistKey, for: .revenueCatAPIKey) {
                print("✅ RevenueCat API key from Info.plist stored in keychain")
            } else {
                print("❌ Failed to store RevenueCat API key from Info.plist")
            }
        } else {
            print("⚠️ No RevenueCat API key found in environment or Info.plist")
        }
    }
    
    /// Legacy method for backward compatibility
    static func initializeAPIKey() {
        initializeAPIKeys()
    }
}

