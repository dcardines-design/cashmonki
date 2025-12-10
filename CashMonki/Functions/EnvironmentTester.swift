//
//  EnvironmentTester.swift
//  CashMonki
//
//  Created by Claude on 12/6/25.
//

import Foundation

/// Test utility to verify environment variable loading and API key configuration
class EnvironmentTester {
    
    /// Test all API key loading mechanisms
    static func testAPIKeyLoading() -> APIKeyTestResult {
        print("🧪 EnvironmentTester: Starting API key loading test...")
        
        var result = APIKeyTestResult()
        
        // Test 1: Environment Variables
        result.environmentVariables = testEnvironmentVariables()
        
        // Test 2: Config System
        result.configSystem = testConfigSystem()
        
        // Test 3: Keychain Storage
        result.keychainStorage = testKeychainStorage()
        
        // Test 4: Full Flow
        result.fullFlow = testFullFlow()
        
        print("🧪 EnvironmentTester: Test completed!")
        return result
    }
    
    // MARK: - Individual Tests
    
    private static func testEnvironmentVariables() -> TestStatus {
        print("🔍 Testing environment variables...")
        
        let requiredKeys = ["OPENROUTER_API_KEY", "REVENUECAT_API_KEY", "REVENUECAT_TEST_API_KEY"]
        var allPresent = true
        
        for key in requiredKeys {
            if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
                print("✅ Environment: \(key) = \(value.prefix(20))...")
            } else {
                print("❌ Environment: \(key) not found")
                allPresent = false
            }
        }
        
        return allPresent ? .success : .failure
    }
    
    private static func testConfigSystem() -> TestStatus {
        print("🔍 Testing Config system...")
        
        var allWorking = true
        
        // Test OpenRouter key
        if let openRouterKey = Config.openRouterAPIKey {
            print("✅ Config: OpenRouter key loaded = \(openRouterKey.prefix(20))...")
        } else {
            print("❌ Config: OpenRouter key not loaded")
            allWorking = false
        }
        
        // Test RevenueCat key
        if let revenueCatKey = Config.revenueCatAPIKey {
            print("✅ Config: RevenueCat key loaded = \(revenueCatKey.prefix(20))...")
        } else {
            print("❌ Config: RevenueCat key not loaded")
            allWorking = false
        }
        
        return allWorking ? .success : .failure
    }
    
    private static func testKeychainStorage() -> TestStatus {
        print("🔍 Testing keychain storage...")
        
        let keychainManager = KeychainManager.shared
        var allStored = true
        
        // Check if keys exist in keychain
        if keychainManager.exists(for: .openRouterAPIKey) {
            if let storedKey = keychainManager.retrieve(for: .openRouterAPIKey) {
                print("✅ Keychain: OpenRouter key stored = \(storedKey.prefix(20))...")
            } else {
                print("⚠️ Keychain: OpenRouter key exists but couldn't retrieve")
                allStored = false
            }
        } else {
            print("❌ Keychain: OpenRouter key not stored")
            allStored = false
        }
        
        if keychainManager.exists(for: .revenueCatAPIKey) {
            if let storedKey = keychainManager.retrieve(for: .revenueCatAPIKey) {
                print("✅ Keychain: RevenueCat key stored = \(storedKey.prefix(20))...")
            } else {
                print("⚠️ Keychain: RevenueCat key exists but couldn't retrieve")
                allStored = false
            }
        } else {
            print("❌ Keychain: RevenueCat key not stored")
            allStored = false
        }
        
        return allStored ? .success : .failure
    }
    
    private static func testFullFlow() -> TestStatus {
        print("🔍 Testing full initialization flow...")
        
        // Initialize the full flow
        EnvironmentLoader.initialize()
        Config.initializeAPIKeys()
        
        // Verify end result
        let openRouterWorks = Config.openRouterAPIKey != nil
        let revenueCatWorks = Config.revenueCatAPIKey != nil
        
        if openRouterWorks && revenueCatWorks {
            print("✅ Full flow: All APIs keys accessible")
            return .success
        } else {
            print("❌ Full flow: Some API keys not accessible")
            return .failure
        }
    }
    
    // MARK: - Security Check
    
    /// Verify no API keys are hardcoded in Info.plist
    static func testInfoPlistSecurity() -> SecurityTestResult {
        print("🛡️ EnvironmentTester: Testing Info.plist security...")
        
        let bundle = Bundle.main
        var result = SecurityTestResult()
        
        // Check OpenRouter key
        if let plistKey = bundle.object(forInfoDictionaryKey: "OpenRouterAPIKey") as? String {
            if plistKey.contains("sk-or-v1-") && !plistKey.contains("YOUR_API_KEY_HERE") {
                result.openRouterExposed = true
                print("⚠️ Security: OpenRouter API key exposed in Info.plist")
            } else {
                result.openRouterSecure = true
                print("✅ Security: OpenRouter API key secured in Info.plist")
            }
        }
        
        // Check RevenueCat key
        if let plistKey = bundle.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String {
            if plistKey.contains("appl_") && !plistKey.contains("YOUR_REVENUECAT_API_KEY_HERE") {
                result.revenueCatExposed = true
                print("⚠️ Security: RevenueCat API key exposed in Info.plist")
            } else {
                result.revenueCatSecure = true
                print("✅ Security: RevenueCat API key secured in Info.plist")
            }
        }
        
        return result
    }
    
    // MARK: - Production Readiness
    
    /// Check if app is ready for production deployment
    static func testProductionReadiness() -> ProductionReadinessResult {
        print("🚀 EnvironmentTester: Testing production readiness...")
        
        var result = ProductionReadinessResult()
        
        // Test 1: API keys work
        result.apiKeysWork = (Config.openRouterAPIKey != nil && Config.revenueCatAPIKey != nil)
        
        // Test 2: Security compliance
        let securityResult = testInfoPlistSecurity()
        result.securityCompliant = securityResult.isSecure
        
        // Test 3: Environment system works
        result.environmentSystemWorks = (ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] != nil)
        
        // Test 4: Keychain integration works
        result.keychainWorks = KeychainManager.shared.exists(for: .openRouterAPIKey)
        
        print("🚀 Production readiness: \(result.isReady ? "✅ READY" : "❌ NOT READY")")
        
        return result
    }
    
    /// Print comprehensive diagnostic report
    static func printDiagnosticReport() {
        print("\n" + String(repeating: "=", count: 60))
        print("🏥 CASHMONKI API KEY DIAGNOSTIC REPORT")
        print(String(repeating: "=", count: 60))
        
        let apiTest = testAPIKeyLoading()
        let securityTest = testInfoPlistSecurity()
        let productionTest = testProductionReadiness()
        
        print("\n📊 API Key Loading Test Results:")
        print("   Environment Variables: \(apiTest.environmentVariables.emoji)")
        print("   Config System: \(apiTest.configSystem.emoji)")
        print("   Keychain Storage: \(apiTest.keychainStorage.emoji)")
        print("   Full Flow: \(apiTest.fullFlow.emoji)")
        
        print("\n🛡️ Security Test Results:")
        print("   Info.plist Security: \(securityTest.isSecure ? "✅ SECURE" : "⚠️ EXPOSED")")
        print("   OpenRouter: \(securityTest.openRouterSecure ? "✅" : "❌")")
        print("   RevenueCat: \(securityTest.revenueCatSecure ? "✅" : "❌")")
        
        print("\n🚀 Production Readiness:")
        print("   Overall Status: \(productionTest.isReady ? "✅ READY FOR PRODUCTION" : "❌ NOT READY")")
        print("   API Keys Work: \(productionTest.apiKeysWork ? "✅" : "❌")")
        print("   Security Compliant: \(productionTest.securityCompliant ? "✅" : "❌")")
        print("   Environment System: \(productionTest.environmentSystemWorks ? "✅" : "❌")")
        print("   Keychain Integration: \(productionTest.keychainWorks ? "✅" : "❌")")
        
        print("\n" + String(repeating: "=", count: 60))
        print("End of Diagnostic Report")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Test Result Models

struct APIKeyTestResult {
    var environmentVariables: TestStatus = .pending
    var configSystem: TestStatus = .pending
    var keychainStorage: TestStatus = .pending
    var fullFlow: TestStatus = .pending
    
    var allPassed: Bool {
        return [environmentVariables, configSystem, keychainStorage, fullFlow].allSatisfy { $0 == .success }
    }
}

struct SecurityTestResult {
    var openRouterSecure: Bool = false
    var revenueCatSecure: Bool = false
    var openRouterExposed: Bool = false
    var revenueCatExposed: Bool = false
    
    var isSecure: Bool {
        return openRouterSecure && revenueCatSecure && !openRouterExposed && !revenueCatExposed
    }
}

struct ProductionReadinessResult {
    var apiKeysWork: Bool = false
    var securityCompliant: Bool = false
    var environmentSystemWorks: Bool = false
    var keychainWorks: Bool = false
    
    var isReady: Bool {
        return apiKeysWork && securityCompliant && environmentSystemWorks && keychainWorks
    }
}

enum TestStatus {
    case pending
    case success
    case failure
    
    var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .success: return "✅"
        case .failure: return "❌"
        }
    }
}

// MARK: - Debug Extension for Settings

#if DEBUG
extension EnvironmentTester {
    /// Quick test method for settings page debug button
    static func quickTest() {
        print("🧪 Running quick environment test...")
        let result = testAPIKeyLoading()
        print("🧪 Result: \(result.allPassed ? "✅ All tests passed" : "❌ Some tests failed")")
    }
}
#endif