#!/usr/bin/env swift

import Foundation

// Simple test to verify environment variables are loaded correctly
print("🧪 Testing Environment Variable Loading...")
print("=" * 50)

// Check environment variables
let requiredKeys = ["OPENROUTER_API_KEY", "REVENUECAT_API_KEY", "REVENUECAT_TEST_API_KEY"]

for key in requiredKeys {
    if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
        print("✅ \(key): \(value.prefix(20))...")
    } else {
        print("❌ \(key): NOT FOUND")
    }
}

print("=" * 50)
print("🧪 Environment test complete!")