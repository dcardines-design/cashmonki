//
//  AccountManager.swift
//  CashMonki
//
//  Created by Claude on 1/22/25.
//

import Foundation
import SwiftUI

class AccountManager: ObservableObject {
    static let shared = AccountManager()
    
    @Published var selectedSubAccountId: UUID?
    @Published var showingAllAccounts: Bool = true
    
    private let userManager = UserManager.shared
    private var hasEnsuredRosebudAccount = false
    private let firestoreService = FirestoreService.shared
    
    private init() {
        // Don't setup accounts immediately - wait for Firebase to load first
        // setupDefaultAccount() will be called after Firebase loading is complete
        
        // Listen for when UserManager completes Firebase loading
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFirebaseLoadComplete),
            name: NSNotification.Name("UserManagerFirebaseLoadComplete"),
            object: nil
        )
    }
    
    @objc private func handleFirebaseLoadComplete() {
        print("🏗️ AccountManager: Firebase load complete, setting up accounts...")
        
        // First, clean up any duplicate accounts before setting up defaults
        cleanupDuplicateRosebudAccounts()
        
        setupDefaultAccount()
    }
    
    // MARK: - Account Selection
    
    var currentSubAccount: SubAccount? {
        guard let selectedId = selectedSubAccountId else { 
            print("🔍 AccountManager.currentSubAccount: No selectedSubAccountId")
            return nil 
        }
        let account = userManager.currentUser.subAccount(withId: selectedId)
        print("🔍 AccountManager.currentSubAccount: Looking for ID \(selectedId.uuidString.prefix(8)), found: \(account?.name ?? "nil")")
        return account
    }
    
    var filteredTransactions: [Txn] {
        print("🔍 AccountManager.filteredTransactions called")
        print("   - selectedSubAccountId: \(selectedSubAccountId?.uuidString.prefix(8) ?? "nil")")
        print("   - defaultSubAccount: \(userManager.currentUser.defaultSubAccount?.id.uuidString.prefix(8) ?? "nil")")
        print("   - total user transactions: \(userManager.currentUser.transactions.count)")
        
        // Debug: Show what walletIDs exist in transactions
        let allTransactions = userManager.currentUser.transactions
        let walletIDs = Set(allTransactions.compactMap { $0.walletID })
        print("   - unique walletIDs in transactions: \(walletIDs.map { $0.uuidString.prefix(8) })")
        
        // Debug: Show available accounts
        let availableAccounts = userManager.currentUser.subAccounts
        print("   - available accounts: \(availableAccounts.map { "\($0.name):\($0.id.uuidString.prefix(8))" })")
        
        // REMOVED: migrateOrphanedTransactions() - causes state modification during view updates
        // Migration will happen at app launch instead
        
        if let selectedId = selectedSubAccountId {
            let transactions = userManager.currentUser.transactions(for: selectedId)
            print("   - transactions for selected account \(selectedId.uuidString.prefix(8)): \(transactions.count)")
            return transactions
        } else {
            // If no account selected, default to the user's default account
            if let defaultAccountId = userManager.currentUser.defaultSubAccount?.id {
                let transactions = userManager.currentUser.transactions(for: defaultAccountId)
                print("   - transactions for default account \(defaultAccountId.uuidString.prefix(8)): \(transactions.count)")
                return transactions
            }
            print("   - no account selected and no default account - returning empty array")
            return []
        }
    }
    
    // MARK: - Transaction Migration
    
    /// Public method to run migration at app startup (safe from main thread)
    func migrateOrphanedTransactionsAtStartup() {
        DispatchQueue.main.async { [weak self] in
            self?.migrateOrphanedTransactions()
        }
    }
    
    private func migrateOrphanedTransactions() {
        print("🔄 AccountManager: Starting orphaned transaction migration...")
        
        guard let defaultAccountId = userManager.currentUser.defaultSubAccount?.id else {
            print("🚨 AccountManager: No default account found for migration")
            return
        }
        
        let availableAccountIds = Set(userManager.currentUser.subAccounts.map { $0.id })
        print("   - Available account IDs: \(availableAccountIds.map { $0.uuidString.prefix(8) })")
        
        let allTransactions = userManager.currentUser.transactions
        var orphanedTransactions: [Txn] = []
        
        // Find transactions that don't belong to any current account
        for transaction in allTransactions {
            if let walletID = transaction.walletID {
                if !availableAccountIds.contains(walletID) {
                    print("   - Found orphaned transaction \(transaction.txID.uuidString.prefix(8)) with walletID \(walletID.uuidString.prefix(8))")
                    orphanedTransactions.append(transaction)
                }
            } else {
                // Transactions with nil walletID are also orphaned
                print("   - Found orphaned transaction \(transaction.txID.uuidString.prefix(8)) with nil walletID")
                orphanedTransactions.append(transaction)
            }
        }
        
        if !orphanedTransactions.isEmpty {
            print("🔄 AccountManager: Found \(orphanedTransactions.count) orphaned transactions, migrating to default account \(defaultAccountId.uuidString.prefix(8))")
            
            // Migrate orphaned transactions to default account
            for orphanedTransaction in orphanedTransactions {
                let updatedTransaction = Txn(
                    txID: orphanedTransaction.txID,
                    accountID: orphanedTransaction.accountID,
                    walletID: defaultAccountId,
                    category: orphanedTransaction.category,
                    categoryId: orphanedTransaction.categoryId,
                    amount: orphanedTransaction.amount,
                    date: orphanedTransaction.date,
                    createdAt: orphanedTransaction.createdAt,
                    hasReceiptImage: orphanedTransaction.hasReceiptImage,
                    merchantName: orphanedTransaction.merchantName,
                    paymentMethod: orphanedTransaction.paymentMethod,
                    receiptNumber: orphanedTransaction.receiptNumber,
                    invoiceNumber: orphanedTransaction.invoiceNumber,
                    items: orphanedTransaction.items,
                    note: orphanedTransaction.note,
                    originalAmount: orphanedTransaction.originalAmount,
                    originalCurrency: orphanedTransaction.originalCurrency,
                    primaryCurrency: orphanedTransaction.primaryCurrency,
                    secondaryCurrency: orphanedTransaction.secondaryCurrency,
                    exchangeRate: orphanedTransaction.exchangeRate,
                    secondaryAmount: orphanedTransaction.secondaryAmount,
                    secondaryExchangeRate: orphanedTransaction.secondaryExchangeRate
                )
                userManager.updateTransaction(updatedTransaction)
            }
            
            print("✅ AccountManager: Migrated \(orphanedTransactions.count) transactions to default account")
        } else {
            print("✅ AccountManager: No orphaned transactions found - all transactions properly assigned")
        }
    }
    
    func selectAccount(_ subAccount: SubAccount) {
        print("🎯 AccountManager.selectAccount: Selecting '\(subAccount.name)' with ID: \(subAccount.id.uuidString)")
        selectedSubAccountId = subAccount.id
        showingAllAccounts = false
        print("🎯 AccountManager.selectAccount: selectedSubAccountId now set to: \(selectedSubAccountId?.uuidString ?? "nil")")
        // Defer objectWillChange to avoid publishing during view updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Account Management
    
    func createSubAccount(
        name: String,
        type: SubAccountType,
        currency: Currency = .php,
        color: Color? = nil,
        makeDefault: Bool = false,
        balance: Double? = nil,
        showBalance: Bool = false
    ) {
        print("🔧 AccountManager: WALLET CREATION DEBUG - Starting wallet creation")
        print("   📝 Name: '\(name)'")
        print("   🎨 Type: \(type.displayName)")
        print("   💰 Currency: \(currency.rawValue)")
        print("   🔵 Make default: \(makeDefault)")
        print("   💵 Balance: \(balance ?? 0)")
        print("   👁️ Show balance: \(showBalance)")
        print("   👤 User: \(userManager.currentUser.name) (\(userManager.currentUser.email))")
        print("   🏦 Current wallet count: \(userManager.currentUser.accounts.count)")

        let colorHex = color?.toHex() ?? type.defaultColor.toHex()

        let newAccount = SubAccount(
            parentUserId: userManager.currentUser.id,
            name: name,
            type: type,
            currency: currency,
            colorHex: colorHex,
            isDefault: makeDefault,
            balance: balance,
            showBalance: showBalance
        )
        
        print("🆔 AccountManager: Created wallet with ID: \(newAccount.id.uuidString)")
        
        // Add to user's accounts
        print("📥 AccountManager: Adding wallet to UserManager...")
        userManager.addSubAccount(newAccount)
        
        print("🏦 AccountManager: Wallet count after add: \(userManager.currentUser.accounts.count)")
        print("🏦 AccountManager: All wallets: \(userManager.currentUser.accounts.map { "\($0.name) (\($0.id.uuidString.prefix(8)))" })")
        
        // If this is the only account or makeDefault is true, set as default
        if userManager.currentUser.accounts.count == 1 || makeDefault {
            print("⭐ AccountManager: Setting wallet as default...")
            setDefaultAccount(newAccount.id)
        }
        
        // CRITICAL: Force local save immediately
        print("💾 AccountManager: FORCE SAVING to local storage...")
        userManager.saveCurrentUserLocally()
        
        // LOCAL FIRST: Only sync to Firebase if user has enabled it
        if userManager.isFirebaseSyncEnabled {
            print("☁️ AccountManager: Firebase sync enabled - starting sync...")
            userManager.syncToFirebase { success in
                if success {
                    print("✅ AccountManager: Account '\(name)' synced to Firebase")
                    print("🔄 AccountManager: Wallet should now persist across app restarts")
                } else {
                    print("❌ AccountManager: Failed to sync account '\(name)' to Firebase")
                    print("⚠️ AccountManager: Wallet saved locally but not in cloud")
                }
            }
        } else {
            print("💾 AccountManager: Firebase sync disabled - wallet saved locally only")
            print("🔄 AccountManager: Local-first approach - wallet will persist across app restarts")
        }
        
        print("✅ AccountManager: Created sub-account '\(name)' of type '\(type.displayName)'")
        print("💾 AccountManager: WALLET PERSISTENCE STATUS:")
        print("   ✅ Added to UserManager.currentUser.accounts")
        print("   ✅ Saved to local storage (UserDefaults)")
        print("   🔄 Firebase sync in progress...")
        print("   📱 Should persist across app restarts")
    }
    
    func deleteSubAccount(_ accountId: UUID) {
        guard let account = userManager.currentUser.subAccount(withId: accountId) else { return }
        
        // Don't allow deleting the last account
        guard userManager.currentUser.subAccounts.count > 1 else {
            print("⚠️ AccountManager: Cannot delete last remaining account")
            return
        }
        
        // If deleting default account, set another as default
        if account.isDefault {
            if let otherAccount = userManager.currentUser.subAccounts.first(where: { $0.id != accountId }) {
                setDefaultAccount(otherAccount.id)
            }
        }
        
        // Remove from user's accounts
        userManager.deleteAccount(withId: accountId)
        
        // If currently selected account was deleted, switch to default
        if selectedSubAccountId == accountId {
            selectedSubAccountId = userManager.currentUser.defaultSubAccount?.id
        }
        
        // Sync deletion to Firebase
        userManager.syncToFirebase { success in
            print(success ? "✅ Account deletion synced to Firebase" : "❌ Failed to sync account deletion to Firebase")
        }
        
        print("🗑️ AccountManager: Deleted sub-account '\(account.name)'")
    }
    
    func setDefaultAccount(_ accountId: UUID) {
        userManager.setDefaultSubAccount(accountId)
        // Sync to Firebase
        userManager.syncToFirebase { success in
            print(success ? "✅ Default account synced to Firebase" : "❌ Failed to sync default account to Firebase")
        }
        // Defer objectWillChange to avoid publishing during view updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func updateSubAccount(_ account: SubAccount) {
        // Convert SubAccount to AccountData for storage compatibility
        let accountData = AccountData(
            id: account.id,
            name: account.name,
            type: account.type == .personal ? .personal : .business,
            currency: account.currency,
            isDefault: account.isDefault,
            balance: account.balance,
            showBalance: account.showBalance
        )
        
        userManager.modifyAccount(accountData)
        // Sync to Firebase
        userManager.syncToFirebase { success in
            print(success ? "✅ Account update synced to Firebase" : "❌ Failed to sync account update to Firebase")
        }
        // Defer objectWillChange to avoid publishing during view updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Transaction Management
    
    func addTransaction(_ transaction: Txn, to subAccountId: UUID? = nil) {
        let targetAccountId = subAccountId ?? selectedSubAccountId ?? userManager.currentUser.defaultSubAccount?.id
        
        guard let accountId = targetAccountId else {
            print("❌ AccountManager: No valid account ID for transaction")
            return
        }
        
        // Create transaction with proper sub-account ID
        let newTransaction = Txn(
            txID: transaction.txID,
            accountID: transaction.accountID,
            walletID: accountId,
            category: transaction.category,
            categoryId: transaction.categoryId,
            amount: transaction.amount,
            date: transaction.date,
            createdAt: transaction.createdAt,
            receiptImage: transaction.receiptImage,
            hasReceiptImage: transaction.hasReceiptImage,
            merchantName: transaction.merchantName,
            paymentMethod: transaction.paymentMethod,
            receiptNumber: transaction.receiptNumber,
            invoiceNumber: transaction.invoiceNumber,
            items: transaction.items,
            note: transaction.note,
            originalAmount: transaction.originalAmount,
            originalCurrency: transaction.originalCurrency,
            primaryCurrency: transaction.primaryCurrency,
            secondaryCurrency: transaction.secondaryCurrency,
            exchangeRate: transaction.exchangeRate,
            secondaryAmount: transaction.secondaryAmount,
            secondaryExchangeRate: transaction.secondaryExchangeRate
        )
        
        // Add to user manager
        userManager.addTransaction(newTransaction)
        
        print("💰 AccountManager: Added transaction to account '\(getAccountName(accountId))'")
    }
    
    func getAccountBalance(for accountId: UUID) -> Double {
        return userManager.currentUser.balance(for: accountId)
    }
    
    func getAccountName(_ accountId: UUID) -> String {
        return userManager.currentUser.subAccount(withId: accountId)?.name ?? "Unknown Account"
    }
    
    // MARK: - Setup & Migration
    
    private func removeRosebudStudioFromPersonalAccounts() {
        print("🧹 AccountManager: Checking for incorrectly added Rosebud Studio accounts...")
        
        let rosebudAccounts = userManager.currentUser.subAccounts.filter { $0.name == "Rosebud Studio" }
        
        if !rosebudAccounts.isEmpty {
            print("🚨 AccountManager: Found \(rosebudAccounts.count) Rosebud Studio account(s) that should be removed from personal user")
            
            for account in rosebudAccounts {
                print("🗑️ AccountManager: Removing Rosebud Studio account: \(account.id.uuidString.prefix(8))")
                
                // Check if this account has any transactions and reassign them to default account
                let accountTransactions = userManager.currentUser.transactions(for: account.id)
                if !accountTransactions.isEmpty {
                    print("   - Account has \(accountTransactions.count) transactions, reassigning to default account")
                    if let defaultAccountId = userManager.currentUser.defaultSubAccount?.id {
                        for transaction in accountTransactions {
                            let updatedTransaction = Txn(
                                txID: transaction.txID,
                                accountID: transaction.accountID,
                                walletID: defaultAccountId,
                                category: transaction.category,
                                categoryId: transaction.categoryId,
                                amount: transaction.amount,
                                date: transaction.date,
                                createdAt: transaction.createdAt,
                                hasReceiptImage: transaction.hasReceiptImage,
                                merchantName: transaction.merchantName,
                                paymentMethod: transaction.paymentMethod,
                                receiptNumber: transaction.receiptNumber,
                                invoiceNumber: transaction.invoiceNumber,
                                items: transaction.items,
                                note: transaction.note,
                                originalAmount: transaction.originalAmount,
                                originalCurrency: transaction.originalCurrency,
                                primaryCurrency: transaction.primaryCurrency,
                                secondaryCurrency: transaction.secondaryCurrency,
                                exchangeRate: transaction.exchangeRate,
                                secondaryAmount: transaction.secondaryAmount,
                                secondaryExchangeRate: transaction.secondaryExchangeRate
                            )
                            userManager.updateTransaction(updatedTransaction)
                        }
                    }
                }
                
                // Delete the Rosebud Studio account
                userManager.deleteAccount(withId: account.id)
            }
            
            // Sync changes to Firebase
            userManager.syncToFirebase { success in
                if success {
                    print("✅ AccountManager: Rosebud Studio account removal synced to Firebase")
                } else {
                    print("❌ AccountManager: Failed to sync Rosebud Studio account removal to Firebase")
                }
            }
            
            print("✅ AccountManager: Rosebud Studio account(s) removed from personal user")
        } else {
            print("✅ AccountManager: No Rosebud Studio accounts found to remove")
        }
    }
    
    private func cleanupDuplicateRosebudAccounts() {
        let rosebudAccounts = userManager.currentUser.subAccounts.filter { $0.name == "Rosebud Studio" }
        
        if rosebudAccounts.count > 1 {
            print("🧹 AccountManager: Found \(rosebudAccounts.count) duplicate Rosebud Studio accounts, cleaning up...")
            
            // Keep the first one, delete the rest
            let accountsToDelete = Array(rosebudAccounts.dropFirst())
            
            for account in accountsToDelete {
                print("🗑️ AccountManager: Removing duplicate Rosebud Studio account: \(account.id.uuidString.prefix(8))")
                userManager.deleteAccount(withId: account.id)
            }
            
            // Sync changes to Firebase
            userManager.syncToFirebase { success in
                if success {
                    print("✅ AccountManager: Duplicate cleanup synced to Firebase")
                } else {
                    print("❌ AccountManager: Failed to sync duplicate cleanup to Firebase")
                }
            }
            
            print("✨ AccountManager: Cleanup complete - \(rosebudAccounts.count - accountsToDelete.count) Rosebud Studio account(s) remaining")
        } else if rosebudAccounts.count == 1 {
            print("✅ AccountManager: Single Rosebud Studio account found, no cleanup needed")
        } else {
            print("⚠️ AccountManager: No Rosebud Studio accounts found")
        }
    }
    
    private func ensureRosebudStudioAccount() {
        // Prevent multiple calls
        guard !hasEnsuredRosebudAccount else {
            print("⚠️ AccountManager: ensureRosebudStudioAccount already called, skipping")
            return
        }
        hasEnsuredRosebudAccount = true
        
        let rosebudAccounts = userManager.currentUser.subAccounts.filter { $0.name == "Rosebud Studio" }
        
        if rosebudAccounts.isEmpty {
            print("🏗️ AccountManager: No Rosebud Studio account found, creating one...")
            
            DispatchQueue.main.async {
                let businessAccount = SubAccount.createBusinessAccount(
                    for: self.userManager.currentUser.id,
                    businessName: "Rosebud Studio"
                )
                self.userManager.addSubAccount(businessAccount)
                print("✅ AccountManager: Rosebud Studio account created")
                
                // Sync to Firebase
                self.userManager.syncToFirebase { success in
                    if success {
                        print("✅ AccountManager: New Rosebud Studio account synced to Firebase")
                    } else {
                        print("❌ AccountManager: Failed to sync new Rosebud Studio account to Firebase")
                    }
                }
                
                // Force UI refresh
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
        } else {
            print("✅ AccountManager: Rosebud Studio account exists, no creation needed")
        }
    }
    
    private func setupDefaultAccount() {
        print("🏗️ AccountManager.setupDefaultAccount called")
        print("   - current accounts: \(userManager.currentUser.accounts.count)")
        
        // If user has no sub-accounts, create default ones
        if userManager.currentUser.accounts.isEmpty {
            print("   - no accounts found, creating default accounts")
            createDefaultAccountsForUser()
        } else {
            print("   - user already has accounts, skipping default account creation")
            print("   - existing accounts: \(userManager.currentUser.subAccounts.map { $0.name })")
            
            // Clean up any accidentally created Rosebud Studio accounts for personal users
            removeRosebudStudioFromPersonalAccounts()
        }
        
        // Always set initial selection to default account (never show "All Accounts")
        let defaultAccountId = userManager.currentUser.defaultSubAccount?.id
        selectedSubAccountId = defaultAccountId
        showingAllAccounts = false
        
        print("   - selected account set to: \(selectedSubAccountId?.uuidString.prefix(8) ?? "nil")")
        print("   - default account is: \(defaultAccountId?.uuidString.prefix(8) ?? "nil")")
        
        // If no default account exists, select the first available account
        if selectedSubAccountId == nil, let firstAccount = userManager.currentUser.subAccounts.first {
            selectedSubAccountId = firstAccount.id
        }
    }
    
    private func createDefaultAccountsForUser() {
        print("🏗️ AccountManager: Creating default accounts for user")
        print("   - User: \(userManager.currentUser.name)")
        
        // Create Personal account (default)
        let personalAccount = SubAccount.createPersonalAccount(for: userManager.currentUser.id)
        userManager.addSubAccount(personalAccount)
        print("   - Created personal account: \(personalAccount.name)")
        
        // Sync to Firebase - convert to SubAccount for saving
        for accountData in userManager.currentUser.accounts {
            let subAccount = SubAccount(
                id: accountData.id,
                parentUserId: userManager.currentUser.id,
                name: accountData.name,
                type: accountData.type == .personal ? .personal : .business,
                currency: accountData.currency,
                isDefault: accountData.isDefault
            )
            saveAccountToFirebase(subAccount)
        }
    }
    
    // MARK: - Firebase Integration
    
    private func saveAccountToFirebase(_ account: SubAccount) {
        // Implementation for saving account to Firebase
        print("☁️ AccountManager: Saving account '\(account.name)' to Firebase")
        // TODO: Implement Firebase save for sub-accounts
    }
    
    private func updateAccountInFirebase(_ accountId: UUID) {
        guard let account = userManager.currentUser.subAccount(withId: accountId) else { return }
        saveAccountToFirebase(account)
    }
    
    private func deleteAccountFromFirebase(_ accountId: UUID) {
        // Implementation for deleting account from Firebase
        print("☁️ AccountManager: Deleting account from Firebase")
        // TODO: Implement Firebase deletion for sub-accounts
    }
    
    // MARK: - Analytics & Reporting
    
    func getAccountSummary() -> [(SubAccount, Double, Int)] {
        return userManager.currentUser.subAccounts.map { account in
            let balance = getAccountBalance(for: account.id)
            let transactionCount = userManager.currentUser.transactions(for: account.id).count
            return (account, balance, transactionCount)
        }
    }
    
    func getMostActiveAccount() -> SubAccount? {
        let summary = getAccountSummary()
        return summary.max(by: { $0.2 < $1.2 })?.0
    }
    
    func getAccountWithHighestBalance() -> SubAccount? {
        let summary = getAccountSummary()
        return summary.max(by: { $0.1 < $1.1 })?.0
    }
    
    // MARK: - Cleanup Methods
    
    func forceCleanupDuplicateIDs() {
        print("🧹 AccountManager: FORCE CLEANUP - Fixing duplicate IDs")
        
        // Get all accounts grouped by ID
        let allAccounts = userManager.currentUser.subAccounts
        print("🔍 Current accounts: \(allAccounts.map { "\($0.name) (\($0.id.uuidString.prefix(8)))" })")
        
        var accountsByID: [UUID: [SubAccount]] = [:]
        for account in allAccounts {
            if accountsByID[account.id] == nil {
                accountsByID[account.id] = []
            }
            accountsByID[account.id]?.append(account)
        }
        
        var totalFixed = 0
        // Fix duplicate IDs by giving new UUIDs to duplicates (keep first, fix rest)
        for (id, accounts) in accountsByID {
            if accounts.count > 1 {
                print("🔍 Found \(accounts.count) accounts with same ID: \(id.uuidString.prefix(8))")
                let accountsToFix = Array(accounts.dropFirst())
                for account in accountsToFix {
                    let newId = UUID()
                    print("🔧 FIXING ID: \(account.name) \(account.id.uuidString.prefix(8)) → \(newId.uuidString.prefix(8))")
                    
                    // Delete old account
                    userManager.deleteAccount(withId: account.id)
                    
                    // Create new account with unique ID
                    let fixedAccount = SubAccount(
                        id: newId,
                        parentUserId: account.parentUserId,
                        name: account.name,
                        type: account.type,
                        currency: account.currency,
                        colorHex: account.colorHex,
                        isDefault: account.isDefault
                    )
                    userManager.addSubAccount(fixedAccount)
                    totalFixed += 1
                }
            }
        }
        
        print("✅ FORCE CLEANUP: Fixed \(totalFixed) duplicate IDs")
        
        // Force UI refresh
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.userManager.objectWillChange.send()
        }
        
        // Sync to Firebase
        userManager.syncToFirebase { success in
            if success {
                print("✅ FORCE CLEANUP: Changes synced to Firebase")
            } else {
                print("❌ FORCE CLEANUP: Failed to sync changes")
            }
        }
    }
}

// MARK: - Preview Helpers
extension AccountManager {
    static func preview() -> AccountManager {
        let manager = AccountManager()
        // Add some preview data
        return manager
    }
}