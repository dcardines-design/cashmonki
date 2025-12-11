//
//  EnvironmentLoader.swift
//  CashMonki
//
//  Created by Claude on 12/6/25.
//

import Foundation

/// Loads environment variables from .env file for development
/// This provides a secure way to manage API keys locally
class EnvironmentLoader {
    
    static let shared = EnvironmentLoader()
    
    private init() {}
    
    /// Load environment variables from .env file
    static func loadEnvironment() {
        guard let envUrl = Bundle.main.url(forResource: ".env", withExtension: nil),
              let envContent = try? String(contentsOf: envUrl, encoding: .utf8) else {
            print("🌍 EnvironmentLoader: No .env file found - using system environment variables")
            return
        }
        
        print("🌍 EnvironmentLoader: Loading environment variables from .env file")
        
        let lines = envContent.components(separatedBy: .newlines)
        for line in lines {
            // Skip comments and empty lines
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse KEY=VALUE format
            let parts = trimmed.components(separatedBy: "=")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                
                // Set environment variable
                setenv(key, value, 1)
                print("🔑 EnvironmentLoader: Loaded \(key)")
            }
        }
    }
    
    /// Initialize environment on app launch
    static func initialize() {
        #if DEBUG
        loadEnvironment()
        #endif
        
        // Verify key environment variables are available
        verifyEnvironment()
    }
    
    /// Verify required environment variables are available
    private static func verifyEnvironment() {
        let requiredKeys = [
            "OPENROUTER_API_KEY",
            "REVENUECAT_API_KEY",
            "REVENUECAT_TEST_API_KEY"
        ]
        
        for key in requiredKeys {
            if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
                print("✅ Environment: \(key) loaded")
            } else {
                print("⚠️ Environment: \(key) not found")
            }
        }
    }
}