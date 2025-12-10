// Temporary script to clean up duplicate accounts
// This will be executed through the app

import Foundation

// Function to be called from the app to clean up duplicates
func cleanupDuplicateAccountsNow() {
    let accountManager = AccountManager.shared
    let userManager = UserManager.shared
    
    // Get all accounts
    let allAccounts = userManager.currentUser.subAccounts
    print("🔍 Current accounts: \(allAccounts.map { $0.name })")
    
    // Find duplicates by name
    var accountsByName: [String: [SubAccount]] = [:]
    for account in allAccounts {
        if accountsByName[account.name] == nil {
            accountsByName[account.name] = []
        }
        accountsByName[account.name]?.append(account)
    }
    
    // Remove duplicates (keep first, remove rest)
    for (name, accounts) in accountsByName {
        if accounts.count > 1 {
            print("🔍 Found \(accounts.count) accounts named '\(name)'")
            let accountsToDelete = Array(accounts.dropFirst())
            for account in accountsToDelete {
                print("🗑️ Deleting duplicate account: \(account.name) (\(account.id.uuidString.prefix(8)))")
                userManager.deleteAccount(withId: account.id)
            }
        }
    }
    
    // Sync to Firebase
    userManager.syncToFirebase { success in
        if success {
            print("✅ Duplicate cleanup synced to Firebase")
        } else {
            print("❌ Failed to sync duplicate cleanup")
        }
    }
    
    print("✅ Duplicate cleanup complete")
}