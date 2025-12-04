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
    /// Automatically uses test key in debug builds and production key in release builds
    static var revenueCatAPIKey: String? {
        #if DEBUG
        // Debug builds: Use test API key for sandbox testing
        if let testKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatTestAPIKey") as? String,
           !testKey.isEmpty {
            print("🧪 CONFIG: Using RevenueCat test API key for debug build")
            return testKey
        }
        #endif
        
        // Priority 1: Check keychain (most secure) - Production key
        if let keychainKey = KeychainManager.shared.retrieve(for: .revenueCatAPIKey) {
            print("🔐 CONFIG: Using RevenueCat production key from keychain")
            return keychainKey
        }
        
        // Priority 2: Check environment variable (for development)
        if let envKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] {
            print("🌍 CONFIG: Using RevenueCat key from environment")
            return envKey
        }
        
        // Priority 3: Check Info.plist production key (better than hardcoded)
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
           !plistKey.isEmpty && plistKey != "YOUR_REVENUECAT_API_KEY_HERE" {
            print("📄 CONFIG: Using RevenueCat production key from Info.plist")
            return plistKey
        }
        
        print("❌ CONFIG: No RevenueCat API key found")
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
        
        // Re-initialize from Info.plist
        initializeRevenueCatKey()
        
        // Verify new key
        if let newKey = revenueCatAPIKey {
            print("✅ CONFIG: New RevenueCat API key loaded: \(newKey.prefix(10))...")
        } else {
            print("❌ CONFIG: Failed to load new RevenueCat API key")
        }
    }
}

