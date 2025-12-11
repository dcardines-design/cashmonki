import Foundation

/// Configuration manager for app settings and API keys
struct Config {
    
    /// Get OpenRouter API key securely
    static var openRouterAPIKey: String? {
        return SecureAPIProvider.getOpenRouterAPIKey()
    }
    
    /// Get RevenueCat API key securely
    static var revenueCatAPIKey: String? {
        return SecureAPIProvider.getRevenueCatAPIKey()
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
        guard !KeychainManager.shared.exists(for: .revenueCatAPIKey) else {
            return
        }
        
        // Try environment variable first
        // USE LIVE API KEY for testing real subscriptions with Apple test account
        if let envKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] {
            if KeychainManager.shared.store(envKey, for: .revenueCatAPIKey) {
                print("✅ RevenueCat LIVE API key stored from environment (testing with Apple sandbox)")
            }
            return
        }
        
        #if DEBUG
        // Fallback to test API key if live key not available
        if let testEnvKey = ProcessInfo.processInfo.environment["REVENUECAT_TEST_API_KEY"] {
            if KeychainManager.shared.store(testEnvKey, for: .revenueCatAPIKey) {
                print("✅ RevenueCat TEST API key stored from environment (fallback)")
            }
            return
        }
        #endif
        
        // DEBUG: Use test fallback key for development
        #if DEBUG
        let fallbackKey = "test_placeholder_key_for_debug"
        if KeychainManager.shared.store(fallbackKey, for: .revenueCatAPIKey) {
            print("✅ RevenueCat TEST API key initialized (DEBUG)")
        }
        #endif
    }
    
    /// Legacy method for backward compatibility
    static func initializeAPIKey() {
        initializeAPIKeys()
    }
    
    /// Force refresh API key from Info.plist (useful when key is updated)
    static func forceRefreshOpenRouterKey() {
        print("🔄 CONFIG: Force refreshing OpenRouter API key...")
        
        // Remove existing key from keychain
        let removed = KeychainManager.shared.delete(for: .openRouterAPIKey)
        print("🗑️ CONFIG: Removed old key from keychain: \(removed)")
        
        // Re-initialize from Info.plist
        initializeOpenRouterKey()
        
        // Verify new key
        if let newKey = openRouterAPIKey {
            print("✅ CONFIG: New API key loaded: \(newKey.prefix(10))...")
        } else {
            print("❌ CONFIG: Failed to load new API key")
        }
    }
    
    /// Force refresh RevenueCat API key from Info.plist
    static func forceRefreshRevenueCatKey() {
        print("🔄 CONFIG: Force refreshing RevenueCat API key...")
        
        // Remove existing key from keychain
        let removed = KeychainManager.shared.delete(for: .revenueCatAPIKey)
        print("🗑️ CONFIG: Removed old RevenueCat key from keychain: \(removed)")
        
        // Re-initialize from environment/Info.plist
        initializeRevenueCatKey()
        
        // Verify new key
        if let newKey = revenueCatAPIKey {
            print("✅ CONFIG: New RevenueCat API key loaded: \(newKey.prefix(10))...")
        } else {
            print("❌ CONFIG: Failed to load new RevenueCat API key")
        }
    }
    
    /// Switch to test API key (DEBUG builds only)
    static func useTestAPIKey() {
        #if DEBUG
        print("🧪 CONFIG: Switching to test API key...")
        let removed = KeychainManager.shared.delete(for: .revenueCatAPIKey)
        print("🗑️ CONFIG: Removed production key: \(removed)")
        initializeRevenueCatKey()
        print("✅ CONFIG: Now using: \(revenueCatAPIKey?.prefix(10) ?? "none")...")
        #endif
    }
    
    /// Force use LIVE API key for testing (DEBUG builds)
    static func useLiveAPIKey() {
        #if DEBUG
        print("🚀 CONFIG: Switching to LIVE API key for testing...")
        let removed = KeychainManager.shared.delete(for: .revenueCatAPIKey)
        print("🗑️ CONFIG: Removed old key: \(removed)")
        initializeRevenueCatKey()
        print("✅ CONFIG: Now using LIVE key: \(revenueCatAPIKey?.prefix(10) ?? "none")...")
        #endif
    }
    
    /// Force clear keychain and use live key for Apple sandbox testing
    static func forceUseLiveKeyForSandboxTesting() {
        #if DEBUG
        print("🚀 CONFIG: Switching to LIVE API key for Apple sandbox testing...")
        let removed = KeychainManager.shared.delete(for: .revenueCatAPIKey)
        print("🗑️ CONFIG: Removed old key: \(removed)")
        initializeRevenueCatKey()
        print("✅ CONFIG: Now using LIVE key for sandbox testing: \(revenueCatAPIKey?.prefix(10) ?? "none")...")
        #endif
    }
}

