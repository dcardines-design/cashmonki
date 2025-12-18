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
        
        // DEBUG: Use actual RevenueCat API key for development
        #if DEBUG
        let fallbackKey = "appl_fDIJnBlvjEbTMquNGkbjPATlooQ"
        if KeychainManager.shared.store(fallbackKey, for: .revenueCatAPIKey) {
            print("✅ RevenueCat API key initialized (DEBUG)")
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
    
    /// Debug helper to show current API key status
    static func debugAPIKeyStatus() {
        print("🔍 CONFIG: === API KEY STATUS ===")
        print("📝 Environment REVENUECAT_API_KEY: \(ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"]?.prefix(10) ?? "NOT SET")...")
        print("🔐 Keychain RevenueCat key: \(revenueCatAPIKey?.prefix(10) ?? "NOT SET")...")
        print("✅ Key exists in keychain: \(KeychainManager.shared.exists(for: .revenueCatAPIKey))")
        if let key = revenueCatAPIKey {
            print("🔍 Key type: \(key.contains("test") ? "TEST" : key.contains("live") ? "LIVE (Legacy)" : key.hasPrefix("appl_") ? "MODERN PUBLIC KEY ✅" : key.hasPrefix("sk_") ? "SECRET KEY (Wrong for iOS)" : "UNKNOWN")")
        }
        print("🔍 CONFIG: === STATUS END ===")
    }
    
    /// Test RevenueCat API connection
    static func testRevenueCatConnection() {
        guard let apiKey = revenueCatAPIKey else {
            print("❌ REVENUECAT TEST: No API key available")
            return
        }
        
        print("🧪 REVENUECAT TEST: Testing API connection...")
        print("🔑 Using API key: \(apiKey.prefix(15))...")
        
        // Test with a simple HTTP request to RevenueCat API
        guard let url = URL(string: "https://api.revenuecat.com/v1/subscribers/test") else { return }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    print("🌐 REVENUECAT TEST: API Response: \(httpResponse.statusCode)")
                    switch httpResponse.statusCode {
                    case 200...299:
                        print("✅ REVENUECAT TEST: API key is VALID and connected!")
                    case 401:
                        print("❌ REVENUECAT TEST: API key is INVALID or wrong")
                    case 404:
                        print("✅ REVENUECAT TEST: API key is valid (404 expected for test user)")
                    default:
                        print("⚠️ REVENUECAT TEST: Unexpected status: \(httpResponse.statusCode)")
                    }
                }
            } catch {
                print("❌ REVENUECAT TEST: Network error: \(error)")
            }
        }
    }
    
    /// Force use your actual API key for testing
    static func useActualRevenueCatKey() {
        print("🔑 CONFIG: Setting actual RevenueCat API key...")
        let removed = KeychainManager.shared.delete(for: .revenueCatAPIKey)
        print("🗑️ CONFIG: Removed old key: \(removed)")
        let actualKey = "appl_fDIJnBlvjEbTMquNGkbjPATlooQ"
        if KeychainManager.shared.store(actualKey, for: .revenueCatAPIKey) {
            print("✅ CONFIG: Actual RevenueCat API key set: \(actualKey.prefix(10))...")
        }
    }
}

