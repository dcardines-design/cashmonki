import Foundation

/// Secure API key provider that protects production keys
struct SecureAPIProvider {
    
    /// Get RevenueCat API key securely based on build configuration
    static func getRevenueCatAPIKey() -> String? {
        // Priority 1: Keychain (most secure)
        if let keychainKey = KeychainManager.shared.retrieve(for: .revenueCatAPIKey) {
            print("✅ SECURE: Using RevenueCat key from keychain")
            return keychainKey
        }
        
        // Priority 2: Environment variables (local development)
        if let envKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] {
            print("✅ SECURE: Using RevenueCat key from environment")
            return envKey
        }
        
        if let testEnvKey = ProcessInfo.processInfo.environment["REVENUECAT_TEST_API_KEY"] {
            print("✅ SECURE: Using RevenueCat TEST key from environment")
            return testEnvKey
        }
        
        // TestFlight builds: Use graceful fallback - no keys in Info.plist for security
        if isTestFlightBuild() {
            print("🔒 SECURE: TestFlight build detected - no API keys in Info.plist for security")
            return nil
        }
        
        // Priority 4: Debug builds only
        #if DEBUG
        if let testKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatTestAPIKey") as? String,
           !testKey.isEmpty {
            print("✅ SECURE: Using RevenueCat TEST key for DEBUG")
            return testKey
        }
        
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
           !plistKey.isEmpty && plistKey != "YOUR_REVENUECAT_API_KEY_HERE" {
            print("⚠️ SECURE: Using RevenueCat production key for DEBUG (not recommended)")
            return plistKey
        }
        #endif
        
        print("❌ SECURE: No RevenueCat API key found")
        return nil
    }
    
    /// Get OpenRouter API key securely
    static func getOpenRouterAPIKey() -> String? {
        // Priority 1: Keychain (most secure)
        if let keychainKey = KeychainManager.shared.retrieve(for: .openRouterAPIKey) {
            print("✅ SECURE: Using OpenRouter key from keychain")
            return keychainKey
        }
        
        // Priority 2: Environment variables (local development)
        if let envKey = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] {
            print("✅ SECURE: Using OpenRouter key from environment")
            return envKey
        }
        
        // TestFlight builds: Use graceful fallback - no keys in Info.plist for security  
        if isTestFlightBuild() {
            print("🔒 SECURE: TestFlight build detected - no API keys in Info.plist for security")
            return nil
        }
        
        // Priority 4: Debug builds only
        #if DEBUG
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OpenRouterAPIKey") as? String,
           !plistKey.isEmpty && plistKey != "YOUR_API_KEY_HERE" {
            print("⚠️ SECURE: Using OpenRouter key for DEBUG")
            return plistKey
        }
        #endif
        
        print("❌ SECURE: No OpenRouter API key found")
        return nil
    }
    
    /// Detect if this is a TestFlight build
    @available(iOS, deprecated: 18.0, message: "Uses legacy receipt URL check")
    private static func isTestFlightBuild() -> Bool {
        // TestFlight builds have a specific receipt format
        // Note: appStoreReceiptURL is deprecated in iOS 18 but still functional
        // Using it for backward compatibility with older iOS versions
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return receiptURL.path.contains("sandboxReceipt")
    }
    
    /// Remove all API keys from Info.plist for production security
    static func clearInfoPlistKeysForProduction() {
        #if !DEBUG
        // In production builds, warn if keys are found in Info.plist
        if let _ = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String {
            print("⚠️ SECURITY WARNING: RevenueCat production key found in Info.plist")
        }
        if let _ = Bundle.main.object(forInfoDictionaryKey: "OpenRouterAPIKey") as? String {
            print("⚠️ SECURITY WARNING: OpenRouter key found in Info.plist") 
        }
        #endif
    }
}