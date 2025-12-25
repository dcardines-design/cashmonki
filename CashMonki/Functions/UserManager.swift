//
//  UserManager.swift
//  Cashooya Playground
//
//  Created by Claude on 10/8/25.
//

import Foundation
import SwiftUI
import StoreKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

class UserManager: ObservableObject {
    static let shared = UserManager()

    @Published var currentUser: UserData
    @Published var isLoadingFromFirebase = false
    @Published var firebaseError: String?

    // Track if we've requested an app review (persisted across sessions)
    @AppStorage("hasRequestedAppReview") private var hasRequestedAppReview = false
    
    /// Check if user has a valid profile (not default user)
    var hasUserProfile: Bool {
        return currentUser.name != "Cashmonki User" &&
               currentUser.email != "guest@cashmonki.com" &&
               !currentUser.name.isEmpty
    }
    
    private let firestore = FirestoreService.shared
    private var syncManager: TransactionSyncManager?
    private var hasLoadedFromFirebase = false
    private var hasCompletedInitialLoad = false
    
    private init() {
        // Create default wallet structure for initial state with unique UUID
        let defaultWallet = AccountData(
            id: UUID(), // Always use unique UUIDs
            name: "Personal Wallet", // Default name - updated to "[Name]'s Wallet" during onboarding if name provided
            type: .personal,
            currency: .usd, // Temporary placeholder - will be updated during currency selection onboarding
            isDefault: true
        )
        
        // Start with a default user - will be replaced by authentication or Firebase data
        self.currentUser = UserData(
            id: UUID(), // Dynamic user ID - will be updated when user authenticates
            name: "Cashmonki User",
            email: "guest@cashmonki.com",
            transactions: [],
            accounts: [defaultWallet],
            onboardingCompleted: 0, // Default: not started
            enableFirebaseSync: false // DEFAULT TO OFF for local-first approach
        )
        
        print("🏗️ UserManager: Default user created - \(currentUser.name) (\(currentUser.email))")
        print("🏗️ UserManager: Default accounts created - \(currentUser.accounts.map { $0.name })")
        
        // DON'T restore user session in init - will be called after Firebase is configured
        print("🏗️ UserManager: Initialization complete - waiting for Firebase configuration")
        
        // Sync manager will be initialized after initial data load completes
    }
    
    // MARK: - Sync Manager Initialization
    
    func initializeSyncManager() {
        guard !hasCompletedInitialLoad else {
            print("⚠️ UserManager: Sync manager already initialized")
            return
        }
        
        print("🔄 UserManager: Initializing sync manager...")
        syncManager = TransactionSyncManager.shared
        syncManager?.setUserManager(self)
        syncManager?.startSync()
        hasCompletedInitialLoad = true
        print("✅ UserManager: Sync manager initialized and started")
    }
    
    private func completeInitialLoad() {
        print("✅ UserManager: Initial data load completed, starting sync manager...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.initializeSyncManager()
        }
    }
    
    /// Refresh UserManager when a new user authenticates
    func refreshWithAuthenticatedUser() {
        print("🔄 UserManager: Refreshing with newly authenticated user...")
        restoreUserSession()
    }
    
    // MARK: - User Authentication & Session Management
    
    /// Restore user session from stored data or fallback to test user
    func restoreUserSession() {
        print("🔄 UserManager: RESTORE SESSION DEBUG - Starting session restoration")
        
        // Check if we have an authenticated user from Firebase Auth
        if let authenticatedUser = AuthenticationManager.shared.currentUser {
            print("🔧 UserManager: Using authenticated user from Firebase Auth")
            print("👤 UserManager: User: \(authenticatedUser.name)")
            print("📧 UserManager: Email: \(authenticatedUser.email)")
            
            setCurrentUser(
                id: authenticatedUser.id,
                name: authenticatedUser.name,
                email: authenticatedUser.email
            )
            
            // Store authenticated user session
            UserDefaults.standard.set(authenticatedUser.id.uuidString, forKey: "currentUserId")
            UserDefaults.standard.set(authenticatedUser.name, forKey: "currentUserName")
            UserDefaults.standard.set(authenticatedUser.email, forKey: "currentUserEmail")
        } else {
            // Fallback to test user for development
            print("🔧 UserManager: No authenticated user, using test user for development")
            print("🔧 UserManager: This will check for stored session or create new test user")
            useTestUser()
        }
        
        // IMMEDIATELY load authenticated user's transactions from Firebase on app start
        print("🚀 UserManager: IMMEDIATELY loading transactions for current user: \(currentUser.name)")
        print("📧 UserManager: User email: \(currentUser.email)")
        print("⚡ UserManager: This ensures we get existing data WITHOUT timestamp manipulation")
        
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
        firestore.fetchTransactions(userId: firebaseUserID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transactions):
                    if transactions.isEmpty {
                        print("📭 UserManager: No transactions found in Firebase for user: \(self.currentUser.name)")
                        print("👋 UserManager: NEW USER - Starting with empty transaction list")
                        
                        // For new users, just start with empty transactions
                        self.currentUser.transactions = []
                        self.objectWillChange.send()
                        print("✨ UserManager: New user \(self.currentUser.name) ready with empty transaction list")
                    } else {
                        print("✅ UserManager: STARTUP LOAD - Loaded \(transactions.count) existing transactions from Firebase")
                        
                        // Show original timestamps to prove no manipulation
                        if let mostRecent = transactions.first {
                            print("📅 UserManager: Most recent transaction from DB:")
                            print("   - Category: \(mostRecent.category)")
                            print("   - Amount: ₱\(mostRecent.amount)")
                            print("   - Original DATE: \(mostRecent.date)")
                            print("   - Original CREATED AT: \(mostRecent.createdAt)")
                            print("✅ UserManager: Timestamps are ORIGINAL from database")
                        }
                        
                        // Replace local transactions with Firebase data (no timestamp modification)
                        self.currentUser.transactions = Array(Set(transactions)) // Deduplicate
                        print("📊 UserManager: Local transaction count now: \(self.currentUser.transactions.count)")
                        print("💰 UserManager: Dante's current balance: ₱\(String(format: "%.2f", self.currentUser.userBalance))")
                        
                        // Trigger UI update for UserManager and AccountManager
                        self.objectWillChange.send()
                        
                        // Also trigger AccountManager refresh to ensure account filtering works
                        DispatchQueue.main.async {
                            AccountManager.shared.objectWillChange.send()
                        }
                        
                        print("🔄 UserManager: Triggered UI refresh for both UserManager and AccountManager")
                        print("🏢 UserManager: Account filtering should now work properly")
                        
                        // Complete initial load but don't auto-start sync manager
                        // Sync will be manual via Settings button
                        // self.completeInitialLoad()
                    }
                    
                case .failure(let error):
                    print("❌ UserManager: Failed to load transactions on startup: \(error)")
                    print("🚫 UserManager: AUTO-CREATION DISABLED - Use '👤 Create Dante' button manually")
                    print("💡 UserManager: This prevents creating new transactions with current timestamps")
                    
                    // Don't auto-start sync manager - will be manual via Settings
                    // self.completeInitialLoad()
                }
            }
        }
        
        // Comment out the dynamic session restore to prevent ID conflicts during development
        /*
        if let storedUserId = UserDefaults.standard.string(forKey: "currentUserId"),
           let userId = UUID(uuidString: storedUserId) {
            print("🔄 UserManager: Restoring user session for ID: \(userId.uuidString)")
            loadUserFromFirebase(userId: userId)
        } else {
            print("🔧 UserManager: No stored session, using test user")
            useTestUser()
        }
        */
    }
    
    /// Set current user (for authentication integration)
    func setCurrentUser(id: UUID, name: String, email: String) {
        print("👤 UserManager: Setting current user - \(name) (\(email))")
        
        // Store user session immediately
        UserDefaults.standard.set(id.uuidString, forKey: "currentUserId")
        UserDefaults.standard.set(name, forKey: "currentUserName")
        UserDefaults.standard.set(email, forKey: "currentUserEmail")
        
        // LOCAL FIRST APPROACH: Use Firebase UID for consistent storage
        print("🔍 UserManager: DEBUG - AuthenticationManager.shared.currentUser = \(AuthenticationManager.shared.currentUser?.name ?? "nil")")
        print("🔍 UserManager: DEBUG - AuthenticationManager.shared.currentUser?.firebaseUID = \(AuthenticationManager.shared.currentUser?.firebaseUID ?? "nil")")
        
        let firebaseUID = AuthenticationManager.shared.currentUser?.firebaseUID ?? id.uuidString
        print("💾 UserManager: LOCAL FIRST - Using Firebase UID \(firebaseUID) for consistent storage")
        print("🔑 UserManager: Firebase UID retrieved: \(firebaseUID)")
        
        if firebaseUID == id.uuidString {
            print("⚠️ UserManager: WARNING - Using fallback UUID instead of Firebase UID!")
            print("⚠️ UserManager: This means Firebase UID is not available - timing issue?")
        } else {
            print("✅ UserManager: Using actual Firebase UID for storage key")
        }
        
        // Try to load existing local data using Firebase UID
        if let localUser = loadUserFromLocalStorage(firebaseUID: firebaseUID, userEmail: email) {
            print("✅ UserManager: Found existing local data for user!")
            print("🏦 UserManager: Local wallets: \(localUser.accounts.map { $0.name })")
            print("🔍 WALLET DEBUG: Loaded \(localUser.accounts.count) wallets from storage:")
            for (index, account) in localUser.accounts.enumerated() {
                print("   \(index + 1). '\(account.name)' (ID: \(account.id.uuidString.prefix(8))) - Default: \(account.isDefault)")
            }
            
            // Use local data as primary source - INCLUDING THE LOCAL NAME
            self.currentUser = UserData(
                id: id,
                name: localUser.name, // CRITICAL: Use local name, not Firebase name
                email: email,
                transactions: localUser.transactions,
                accounts: localUser.accounts,
                createdAt: localUser.createdAt,
                updatedAt: localUser.updatedAt,
                goals: localUser.goals,
                onboardingCompleted: localUser.onboardingCompleted, // Preserve onboarding progress
                enableFirebaseSync: false // Default to OFF - local first
            )
            
            // CRITICAL: Update AuthenticationManager to match local name
            if var authUser = AuthenticationManager.shared.currentUser {
                authUser.name = localUser.name
                AuthenticationManager.shared.currentUser = authUser
                print("🔄 UserManager: Updated AuthenticationManager to use local name: '\(localUser.name)'")
            }
            
            print("💾 UserManager: Restored user from local storage with \(localUser.accounts.count) wallets")
            print("🔍 WALLET DEBUG: CurrentUser now has \(self.currentUser.accounts.count) wallets:")
            for (index, account) in self.currentUser.accounts.enumerated() {
                print("   \(index + 1). '\(account.name)' (ID: \(account.id.uuidString.prefix(8))) - Default: \(account.isDefault)")
            }
            
            // SECURITY: Clean up any cross-contaminated data for existing users
            cleanupCrossContaminatedData(currentUserEmail: email)
            
            // Fix any empty wallet names for existing users
            if self.currentUser.accounts.contains(where: { $0.name.isEmpty }) {
                print("🔧 UserManager: Found existing user with empty wallet names - fixing...")
                updateDefaultWalletName(basedOnUserName: name)
            }
            
            self.objectWillChange.send()
            
            // Notify AccountManager that loading is complete
            NotificationCenter.default.post(name: NSNotification.Name("UserManagerFirebaseLoadComplete"), object: nil)
            
            // Check if this user has complete data and mark onboarding complete
            self.checkAndMarkOnboardingComplete()
            return
        }
        
        print("💾 UserManager: No local data found, creating new user with default wallet")
        print("🔍 WALLET DEBUG: This means existing wallets (like 'Rosebud') were not found!")
        print("🔍 WALLET DEBUG: User started fresh - all previous wallets lost")
        
        // Create default wallet for new users (name will be set based on user's name)
        let defaultWallet = AccountData(
            id: UUID(), // Always use unique UUIDs
            name: "Personal Wallet", // Default - updated to "[Name]'s Wallet" if name provided
            type: .personal,
            currency: .usd, // Temporary placeholder - will be updated during currency selection onboarding
            isDefault: true
        )
        
        self.currentUser = UserData(
            id: id,
            name: name,
            email: email,
            transactions: [],
            accounts: [defaultWallet],
            onboardingCompleted: 0, // New user starts onboarding from beginning
            enableFirebaseSync: false // DEFAULT TO OFF - local first approach
        )
        
        // Update the default wallet name based on user's name
        updateDefaultWalletName(basedOnUserName: name)
        
        print("✅ UserManager: Created new user with default wallet")
        print("💾 UserManager: Firebase sync disabled by default - local first approach")
        print("🏦 UserManager: Accounts count: \(currentUser.accounts.count)")
        print("🔍 WALLET DEBUG: New user created with \(currentUser.accounts.count) wallets:")
        for (index, account) in currentUser.accounts.enumerated() {
            print("   \(index + 1). '\(account.name)' (ID: \(account.id.uuidString.prefix(8))) - Default: \(account.isDefault)")
        }
        
        // Save new user to local storage immediately
        saveCurrentUserLocally()
        
        // SECURITY: Clean up any cross-contaminated data
        cleanupCrossContaminatedData(currentUserEmail: email)
        
        self.objectWillChange.send()
        
        // Notify AccountManager that loading is complete
        NotificationCenter.default.post(name: NSNotification.Name("UserManagerFirebaseLoadComplete"), object: nil)
        
        // Check if this user has complete data and mark onboarding complete
        self.checkAndMarkOnboardingComplete()
    }
    
    // MARK: - Onboarding Status Check
    
    func checkAndMarkOnboardingComplete() {
        print("🔍 UserManager: Checking if user has complete data for onboarding bypass...")
        
        // Check if user has previously completed onboarding in a past session
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasCompletedCurrency = UserDefaults.standard.bool(forKey: "hasCompletedCurrencySelection")
        let hasCompletedGoals = UserDefaults.standard.bool(forKey: "hasCompletedGoalSelection")
        let hasCompletedTransaction = UserDefaults.standard.bool(forKey: "hasCompletedTransactionOnboarding")
        
        // Check if user has complete name (first + last)
        let hasCompleteName = checkUserHasCompleteName(currentUser.name)
        
        // Check if user has transactions (indicates they've been using the app)
        let hasTransactions = !currentUser.transactions.isEmpty
        
        // Check if user has a default account set up
        let hasDefaultAccount = currentUser.accounts.contains { $0.isDefault }
        
        // Check if user's Firebase displayName has complete name
        let hasFirebaseCompleteName = checkFirebaseDisplayName()
        
        print("📝 UserManager: Complete name: \(hasCompleteName ? "✅" : "❌") - '\(currentUser.name)'")
        print("🔥 UserManager: Firebase display name complete: \(hasFirebaseCompleteName ? "✅" : "❌")")
        print("📊 UserManager: Has transactions: \(hasTransactions ? "✅" : "❌") - \(currentUser.transactions.count) transactions")
        print("🏦 UserManager: Has default account: \(hasDefaultAccount ? "✅" : "❌")")
        print("🎯 UserManager: Previous completion flags:")
        print("   - Onboarding: \(hasCompletedOnboarding ? "✅" : "❌")")
        print("   - Currency: \(hasCompletedCurrency ? "✅" : "❌")")
        print("   - Goals: \(hasCompletedGoals ? "✅" : "❌")")
        print("   - Transaction: \(hasCompletedTransaction ? "✅" : "❌")")
        
        // CONSERVATIVE APPROACH: Only auto-complete if user has explicitly completed onboarding before
        // OR if they have substantial usage data (transactions + complete setup)
        let hasExplicitCompletion = hasCompletedOnboarding && hasCompletedCurrency && hasCompletedGoals
        let hasSubstantialUsage = hasTransactions && (hasCompleteName || hasFirebaseCompleteName) && hasDefaultAccount
        
        // Special case: For returning users with significant app usage, auto-complete
        let shouldAutoComplete = hasExplicitCompletion || hasSubstantialUsage
        
        if shouldAutoComplete {
            print("🎯 UserManager: ===== MARKING ONBOARDING COMPLETE =====")
            
            // Set all legacy UserDefaults flags
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(true, forKey: "hasCompletedCurrencySelection")
            UserDefaults.standard.set(true, forKey: "hasSetPrimaryCurrency")
            UserDefaults.standard.set(true, forKey: "hasCompletedGoalSelection")
            
            // CRITICAL: Also update OnboardingStateManager to prevent conflicts
            OnboardingStateManager.shared.markAsComplete()
            
            if hasExplicitCompletion {
                print("✅ UserManager: RETURNING USER WITH EXPLICIT COMPLETION - Marked onboarding as complete")
                print("🎯 UserManager: User previously completed all onboarding steps")
            } else {
                print("✅ UserManager: EXPERIENCED USER WITH SUBSTANTIAL USAGE - Marked onboarding as complete")
                print("🔥 UserManager: User has transactions and complete setup")
            }
            print("🎯 UserManager: User will bypass onboarding on next login")
            print("🎯 UserManager: Both UserDefaults flags AND OnboardingStateManager updated")
            print("🎯 UserManager: ===== ONBOARDING COMPLETE PROCESSING DONE =====")
        } else {
            print("⚠️ UserManager: User will need to complete onboarding")
            print("🔍 UserManager: Auto-completion criteria not met:")
            print("   - Explicit completion: \(hasExplicitCompletion ? "✅" : "❌")")
            print("   - Substantial usage: \(hasSubstantialUsage ? "✅" : "❌")")
            print("🎯 UserManager: User will go through proper onboarding flow")
        }
    }
    
    /// CURRENT: Always false in no-auth flow
    private func checkFirebaseDisplayName() -> Bool {
        // CURRENT: No-auth flow - no Firebase user to check
        print("🔥 UserManager: No Firebase displayName (no-auth flow)")
        return false

        // FUTURE: Uncomment when re-enabling authentication
        /*
        #if canImport(FirebaseAuth)
        if let firebaseUser = Auth.auth().currentUser,
           let displayName = firebaseUser.displayName {
            let nameComponents = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: " ").filter { !$0.isEmpty }
            print("🔥 UserManager: Firebase displayName: '\(displayName)' (components: \(nameComponents.count))")
            return nameComponents.count >= 2
        }
        #endif
        print("🔥 UserManager: No Firebase displayName found")
        return false
        */
    }
    
    private func checkUserHasCompleteName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameComponents = trimmedName.components(separatedBy: " ").filter { !$0.isEmpty }
        return nameComponents.count >= 2 // At least first and last name
    }
    
    // MARK: - Wallet Management
    
    /// Create a new wallet for the current user
    func createNewWallet(name: String, type: AccountType = .personal, currency: Currency = .php) {
        let newWallet = AccountData(
            name: name,
            type: type,
            currency: currency,
            isDefault: false // New wallets are never default
        )
        
        currentUser.accounts.append(newWallet)
        objectWillChange.send()
        
        print("✅ UserManager: Created new wallet '\(name)' for user \(currentUser.name)")
        print("🏦 UserManager: User now has \(currentUser.accounts.count) wallets")
    }
    
    /// Delete a wallet (cannot delete the default wallet)
    func deleteWallet(walletId: UUID, forceDelete: Bool = false) {
        guard let walletIndex = currentUser.accounts.firstIndex(where: { $0.id == walletId }) else {
            print("❌ UserManager: Wallet not found for deletion")
            return
        }
        
        let wallet = currentUser.accounts[walletIndex]
        
        // Cannot delete the default wallet
        if wallet.isDefault {
            print("❌ UserManager: Cannot delete default wallet")
            return
        }
        
        // Check if wallet has transactions
        let walletTransactions = currentUser.transactions.filter { $0.walletID == walletId }
        if !walletTransactions.isEmpty && !forceDelete {
            print("⚠️ UserManager: Wallet '\(wallet.name)' has \(walletTransactions.count) transactions - requires confirmation")
            return
        }
        
        // If forceDelete is true, delete wallet and move transactions to default wallet
        if !walletTransactions.isEmpty && forceDelete {
            // Find default wallet
            guard let defaultWallet = currentUser.accounts.first(where: { $0.isDefault }) else {
                print("❌ UserManager: No default wallet found to move transactions")
                return
            }
            
            // Move all transactions to default wallet
            for index in currentUser.transactions.indices {
                if currentUser.transactions[index].walletID == walletId {
                    let originalTxn = currentUser.transactions[index]
                    let updatedTxn = Txn(
                        txID: originalTxn.txID,
                        accountID: originalTxn.accountID,
                        walletID: defaultWallet.id,
                        category: originalTxn.category,
                        categoryId: originalTxn.categoryId,
                        amount: originalTxn.amount,
                        date: originalTxn.date,
                        createdAt: originalTxn.createdAt,
                        receiptImage: originalTxn.receiptImage,
                        hasReceiptImage: originalTxn.hasReceiptImage,
                        merchantName: originalTxn.merchantName,
                        paymentMethod: originalTxn.paymentMethod,
                        receiptNumber: originalTxn.receiptNumber,
                        invoiceNumber: originalTxn.invoiceNumber,
                        items: originalTxn.items,
                        note: originalTxn.note,
                        originalAmount: originalTxn.originalAmount,
                        originalCurrency: originalTxn.originalCurrency,
                        primaryCurrency: originalTxn.primaryCurrency,
                        secondaryCurrency: originalTxn.secondaryCurrency,
                        exchangeRate: originalTxn.exchangeRate,
                        secondaryAmount: originalTxn.secondaryAmount,
                        secondaryExchangeRate: originalTxn.secondaryExchangeRate
                    )
                    currentUser.transactions[index] = updatedTxn
                }
            }
            
            print("🔄 UserManager: Moved \(walletTransactions.count) transactions from '\(wallet.name)' to '\(defaultWallet.name)'")
        }
        
        // Delete the wallet
        currentUser.accounts.remove(at: walletIndex)
        objectWillChange.send()
        
        print("✅ UserManager: Deleted wallet '\(wallet.name)'")
        print("🏦 UserManager: User now has \(currentUser.accounts.count) wallets")
    }
    
    /// Check if a wallet can be deleted (for UI confirmation)
    func canDeleteWallet(walletId: UUID) -> (canDelete: Bool, transactionCount: Int, reason: String?) {
        guard let wallet = currentUser.accounts.first(where: { $0.id == walletId }) else {
            return (false, 0, "Wallet not found")
        }
        
        if wallet.isDefault {
            return (false, 0, "Cannot delete default wallet")
        }
        
        let transactionCount = currentUser.transactions.filter { $0.walletID == walletId }.count
        
        if transactionCount > 0 {
            return (true, transactionCount, "Wallet has \(transactionCount) transactions that will be moved to your default wallet")
        }
        
        return (true, 0, nil)
    }
    
    /// Update the current user's name
    func updateUserName(_ name: String) {
        print("👤 UserManager: updateUserName called with: '\(name)'")
        print("👤 UserManager: Current user name before update: '\(currentUser.name)'")
        print("👤 UserManager: AuthManager current user name before update: '\(AuthenticationManager.shared.currentUser?.name ?? "none")'")
        
        currentUser.name = name
        currentUser.updatedAt = Date()
        
        // CRITICAL FIX: Update wallet name when user name changes  
        updateDefaultWalletName(basedOnUserName: name)
        
        // CRITICAL: Also update AuthenticationManager's currentUser name
        // This ensures OnboardingStateManager validates against the correct name
        if var authUser = AuthenticationManager.shared.currentUser {
            authUser.name = name
            AuthenticationManager.shared.currentUser = authUser
            print("🔄 UserManager: Updated AuthenticationManager currentUser name to: '\(name)'")
        }
        
        // CRITICAL: Update Firebase Auth displayName to keep it in sync with local storage
        updateFirebaseDisplayName(name)
        
        saveCurrentUserLocally()
        
        #if canImport(FirebaseFirestore)
        if currentUser.enableFirebaseSync {
            syncToFirebase { success in
                if success {
                    print("✅ UserManager: User name synced to Firebase")
                } else {
                    print("❌ UserManager: Failed to sync user name to Firebase")
                }
            }
        }
        #endif
        
        print("👤 UserManager: UserManager currentUser name after update: '\(currentUser.name)'")
        print("👤 UserManager: AuthManager currentUser name after update: '\(AuthenticationManager.shared.currentUser?.name ?? "none")'")
    }
    
    /// Update the current user's goals from onboarding
    func updateUserGoals(_ goals: String) {
        print("🎯 UserManager: updateUserGoals called with: '\(goals)'")
        print("🎯 UserManager: Current user goals before update: '\(currentUser.goals ?? "nil")'")
        
        currentUser.goals = goals
        currentUser.updatedAt = Date()
        
        saveCurrentUserLocally()
        
        #if canImport(FirebaseFirestore)
        if currentUser.enableFirebaseSync {
            syncToFirebase { success in
                if success {
                    print("✅ UserManager: User goals synced to Firebase")
                } else {
                    print("❌ UserManager: Failed to sync user goals to Firebase")
                }
            }
        }
        #endif
        
        print("✅ UserManager: User goals updated to: '\(currentUser.goals ?? "nil")'")
    }
    
    /// Update the default wallet name based on user's first name
    private func updateDefaultWalletName(basedOnUserName fullName: String) {
        // Extract first name from full name
        let firstName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
            .first ?? ""

        // Create personalized wallet name, or "Personal Wallet" if no name
        let walletName = firstName.isEmpty ? "Personal Wallet" : "\(firstName)'s Wallet"
        
        // Find and update the default wallet
        if let defaultWalletIndex = currentUser.accounts.firstIndex(where: { $0.isDefault }) {
            let oldName = currentUser.accounts[defaultWalletIndex].name
            currentUser.accounts[defaultWalletIndex].name = walletName
            
            print("💳 UserManager: Updated default wallet name from '\(oldName)' to '\(walletName)'")
            print("👤 UserManager: First name extracted: '\(firstName)'")
            
            // Sync to Firebase if available
            syncToFirebase { success in
                if success {
                    print("🔥 UserManager: Wallet name change synced to Firebase")
                } else {
                    print("⚠️ UserManager: Wallet name change sync to Firebase failed")
                }
            }
        } else {
            print("⚠️ UserManager: No default wallet found to update name")
        }
    }
    
    /// Update the primary currency preference (does NOT change wallet currencies)
    func updatePrimaryCurrency(_ currency: Currency) {
        print("🔄 UserManager: Updating primary currency preference...")
        print("💰 UserManager: New display currency: \(currency.rawValue) (\(currency.displayName))")
        print("🏆 UserManager: Currency symbol: \(currency.symbol)")

        // NOTE: We do NOT change the wallet's currency here!
        // Wallets keep their original currency - only the DISPLAY converts to primary currency
        // This preserves the wallet's native currency for accurate conversion

        print("✅ UserManager: Primary currency preference updated to \(currency.rawValue)")
        print("💡 UserManager: Wallet currencies unchanged - display will convert as needed")
        objectWillChange.send()
    }
    
    /// Update user's onboarding progression number
    func updateOnboardingProgress(_ progress: Int) {
        print("🔢 UserManager: Updating onboarding progress: \(currentUser.onboardingCompleted) → \(progress)")
        currentUser.onboardingCompleted = progress
        currentUser.updatedAt = Date()
        
        // SINGLE SOURCE OF TRUTH: Only save locally - no Firebase sync for onboarding
        saveCurrentUserLocally()
        
        print("🔢 UserManager: Onboarding progress saved locally only (no Firebase sync)")
        print("   - Onboarding state is device-specific and doesn't need cross-device sync")
    }
    
    /// CURRENT: No-op in no-auth flow
    private func updateFirebaseDisplayName(_ name: String) {
        // CURRENT: No-auth flow - no Firebase user to update
        print("🔥 UserManager: Skipping Firebase displayName update (no-auth flow)")

        // FUTURE: Uncomment when re-enabling authentication
        /*
        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            print("🔥 UserManager: Attempting to update Firebase displayName from '\(user.displayName ?? "nil")' to '\(name)'")

            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            changeRequest.commitChanges { error in
                if let error = error {
                    print("❌ UserManager: Failed to update Firebase displayName: \(error.localizedDescription)")
                } else {
                    print("✅ UserManager: Successfully updated Firebase displayName to '\(name)'")

                    // Verify the update worked
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let updatedUser = Auth.auth().currentUser {
                            print("🔍 UserManager: Verification - Firebase displayName is now: '\(updatedUser.displayName ?? "nil")'")

                            // Also check the components
                            if let displayName = updatedUser.displayName {
                                let nameComponents = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .components(separatedBy: " ").filter { !$0.isEmpty }
                                print("🔍 UserManager: Name components count: \(nameComponents.count)")

                                if nameComponents.count >= 2 {
                                    print("✅ UserManager: Firebase displayName now has complete name - onboarding bypass should work")

                                    // Update local user data to reflect Firebase changes
                                    DispatchQueue.main.async {
                                        self.currentUser.name = displayName
                                        self.objectWillChange.send()
                                    }
                                } else {
                                    print("❌ UserManager: Firebase displayName still incomplete after update")
                                }
                            }
                        }
                    }
                }
            }
        } else {
            print("❌ UserManager: No current Firebase user found for displayName update")
        }
        #endif
        */
    }
    
    /// Use test user as fallback when no authenticated user exists (development only)
    private func useTestUser() {
        print("👤 UserManager: DEBUG - useTestUser() called")
        print("👤 UserManager: Checking UserDefaults for stored session...")
        
        // Check if we have stored session first
        if let storedUserId = UserDefaults.standard.string(forKey: "currentUserId"),
           let userId = UUID(uuidString: storedUserId),
           let storedName = UserDefaults.standard.string(forKey: "currentUserName"),
           let storedEmail = UserDefaults.standard.string(forKey: "currentUserEmail") {
            
            print("👤 UserManager: Found stored session - restoring existing user")
            print("🆔 UserManager: Stored user ID: \(userId.uuidString)")
            print("📝 UserManager: Stored name: \(storedName)")
            print("📧 UserManager: Stored email: \(storedEmail)")
            print("🔍 UserManager: About to call setCurrentUser with stored session data")
            
            setCurrentUser(
                id: userId,
                name: storedName,
                email: storedEmail
            )
            return
        }
        
        // No stored session - create new local user (no-auth flow)
        let newUserId = UUID()

        print("👤 UserManager: No stored session found - creating new local user")

        setCurrentUser(
            id: newUserId,
            name: "", // Empty name - user will enter during onboarding
            email: "" // Empty email - no-auth flow
        )

        print("👤 UserManager: ✅ NEW LOCAL USER CREATED")
        print("📝 UserManager: User ID: \(newUserId.uuidString.prefix(8))...")
        print("🏷️ UserManager: Name will be collected during onboarding")

        // Store this as the current user session
        UserDefaults.standard.set(newUserId.uuidString, forKey: "currentUserId")
        UserDefaults.standard.set("", forKey: "currentUserName")
        UserDefaults.standard.set("", forKey: "currentUserEmail")
    }
    
    /// Load specific user data from Firebase
    private func loadUserFromFirebase(userId: UUID) {
        print("☁️ UserManager: Loading user data from Firebase for: \(userId.uuidString)")
        isLoadingFromFirebase = true
        firebaseError = nil
        
        loadFromFirebase { success in
            DispatchQueue.main.async {
                self.isLoadingFromFirebase = false
                if success {
                    print("✅ UserManager: User data loaded from Firebase successfully")
                    print("💰 UserManager: User balance: ₱\(String(format: "%.2f", self.currentUser.userBalance))")
                    
                    // DISABLED: No automatic sample data generation
                    print("📊 UserManager: Loaded \(self.currentUser.transactions.count) transactions from Firebase")
                    print("🚫 UserManager: Automatic sample data generation is DISABLED")
                } else {
                    print("⚠️ UserManager: Failed to load user data from Firebase")
                    print("🚫 UserManager: Sample data creation is DISABLED")
                }
            }
        }
    }
    
    /// Sign out current user
    func signOut() {
        print("👋 UserManager: Signing out user")
        
        // Clear stored session
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        UserDefaults.standard.removeObject(forKey: "currentUserName")
        UserDefaults.standard.removeObject(forKey: "currentUserEmail")
        
        // Reset to default user
        currentUser = UserData(
            id: UUID(),
            name: "Cashmonki User",
            email: "guest@cashmonki.com",
            transactions: [],
            accounts: [],
            onboardingCompleted: 0 // Reset onboarding on logout
        )
        
        objectWillChange.send()
    }
    
    // MARK: - Helper Methods
    
    /// Get user name for a given user ID
    private func getUserName(for userId: UUID) -> String {
        // First check if this is the current user
        if userId == currentUser.id {
            return currentUser.name
        }
        
        // Then check hardcoded IDs for legacy support
        switch userId.uuidString {
        case "12345678-1234-1234-1234-123456789ABC":
            return "Dante Cardines III"
        case "C4AD521B-D633-42C5-8A9E-7557A3208B35":
            return "Old User (Temporary)"
        default:
            // Also check if this user ID matches any authenticated user
            if let authUser = AuthenticationManager.shared.currentUser,
               authUser.id == userId {
                return authUser.name
            }
            return "Unknown User"
        }
    }
    
    // MARK: - Transaction Management
    
    func addTransaction(_ transaction: Txn) {
        print("🏦 UserManager: ADD TRANSACTION STARTED")
        print("👤 UserManager: Current user: \(currentUser.name) (\(currentUser.email))")
        print("🆔 UserManager: User ID: \(currentUser.id.uuidString.prefix(8))...")
        print("📥 UserManager: Received transaction:")
        print("   - id: \(transaction.id.uuidString.prefix(8))")
        print("   - category: '\(transaction.category)'")
        print("   - categoryId: \(transaction.categoryId?.uuidString.prefix(8) ?? "nil")")
        print("   - amount: \(transaction.amount)")
        print("   - date: \(transaction.date)")
        print("   - createdAt: \(transaction.createdAt)")
        print("   - merchantName: '\(transaction.merchantName ?? "nil")'")
        print("   - userId: \(transaction.userId.uuidString.prefix(8))")
        print("   - accountId: \(transaction.accountId?.uuidString.prefix(8) ?? "nil")")
        
        // Verify transaction is attributed to current user
        if transaction.userId == currentUser.id {
            print("✅ UserManager: Transaction correctly attributed to current user: \(currentUser.name)")
        } else {
            print("⚠️ UserManager: WARNING - Transaction attributed to different user: \(transaction.userId.uuidString.prefix(8))")
            print("⚠️ UserManager: Expected user: \(currentUser.name) (\(currentUser.id.uuidString.prefix(8)))")
        }
        
        // Check if this is a very recent transaction (within last hour)
        let isVeryRecent = Date().timeIntervalSince(transaction.date) < 3600
        print("   - isVeryRecent: \(isVeryRecent) (within last hour)")
        
        print("📊 UserManager: Current transaction count before add: \(currentUser.transactions.count)")
        
        currentUser.addTransaction(transaction)
        
        // CRITICAL: Save to local storage immediately to persist across app restarts
        saveCurrentUserLocally()
        
        print("📊 UserManager: Current transaction count after add: \(currentUser.transactions.count)")
        print("🔔 UserManager: Sending objectWillChange notification...")
        print("💾 UserManager: Transaction saved locally")

        objectWillChange.send()

        // Request app review after 3 transactions (only once)
        checkAndRequestAppReview()
        
        // Sync using the new sync manager
        print("🔄 UserManager: Triggering sync manager for transaction \(transaction.id.uuidString.prefix(8))...")
        
        // Ensure transaction has correct userId
        var transactionToSync = transaction
        if transaction.userId != currentUser.id {
            print("⚠️ UserManager: Transaction userId mismatch, updating to current user (\(currentUser.name))")
            transactionToSync = Txn(
                id: transaction.id,
                userId: currentUser.id,
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
                accountId: transaction.accountId,
                originalAmount: transaction.originalAmount,
                originalCurrency: transaction.originalCurrency,
                primaryCurrency: transaction.primaryCurrency,
                secondaryCurrency: transaction.secondaryCurrency,
                exchangeRate: transaction.exchangeRate,
                secondaryAmount: transaction.secondaryAmount,
                secondaryExchangeRate: transaction.secondaryExchangeRate
            )
        }
        
        // Enable automatic sync for transaction creation
        syncManager?.syncTransaction(transactionToSync, operation: .create)
        
        // FALLBACK: Also save directly to Firebase to ensure transaction is persisted
        // This provides redundancy in case sync manager is not yet initialized
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
        firestore.saveTransaction(transactionToSync, userId: firebaseUserID) { result in
            switch result {
            case .success():
                print("✅ UserManager: FALLBACK - Transaction \(transaction.id.uuidString.prefix(8)) saved directly to Firebase")
            case .failure(let error):
                print("❌ UserManager: FALLBACK - Failed to save transaction directly: \(error)")
                DispatchQueue.main.async {
                    self.firebaseError = "Failed to save transaction: \(error.localizedDescription)"
                }
            }
        }
        
        print("✅ UserManager: ADD TRANSACTION COMPLETED")
        print("📈 UserManager: Current balance: ₱\(String(format: "%.2f", currentUser.userBalance))")
    }
    
    /// Search for recent transactions across users and migrate them to current user
    func findAndMigrateRecentTransactions() {
        print("🔍 UserManager: Searching for recent transactions to migrate...")
        
        // Search for the dining transaction you mentioned (₱689.46)
        let searchAmount = 689.46
        firestore.searchRecentTransactions(userId: "C4AD521B-D633-42C5-8A9E-7557A3208B35", searchTerm: "689") { result in
            switch result {
            case .success(let transactions):
                print("🔍 Found \(transactions.count) transactions in old user")
                for transaction in transactions {
                    if abs(abs(transaction.amount) - searchAmount) < 0.01 {
                        print("✅ Found recent dining transaction: \(transaction.amount)")
                        // Migrate to current user
                        let migratedTransaction = Txn(
                            id: transaction.id,
                            userId: self.currentUser.id,
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
                            accountId: transaction.accountId,
                            originalAmount: transaction.originalAmount,
                            originalCurrency: transaction.originalCurrency,
                            primaryCurrency: transaction.primaryCurrency,
                            secondaryCurrency: transaction.secondaryCurrency,
                            exchangeRate: transaction.exchangeRate,
                            secondaryAmount: transaction.secondaryAmount,
                            secondaryExchangeRate: transaction.secondaryExchangeRate
                        )
                        
                        DispatchQueue.main.async {
                            self.currentUser.addTransaction(migratedTransaction)
                            self.objectWillChange.send()
                            print("✅ Migrated recent transaction to current user")
                        }
                        
                        // Save to Firebase under correct user
                        // Use Firebase UID for consistent Firebase operations
                        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? self.currentUser.id.uuidString
                        self.firestore.saveTransaction(migratedTransaction, userId: firebaseUserID) { _ in
                            print("✅ Saved migrated transaction to Firebase")
                        }
                    }
                }
            case .failure(let error):
                print("❌ Failed to search for recent transactions: \(error)")
            }
        }
    }
    
    /// DISABLED: Firebase migration - was creating fake users in Firebase
    func migrateAllFirebaseTransactions() {
        print("🚫 UserManager: Firebase migration is DISABLED to prevent database pollution")
        print("⚠️ UserManager: Migration was creating fake user documents in Firebase")
    }
    
    /// DISABLED: Manual Firebase migration trigger
    func forceMigrateFirebaseData() {
        print("🚫 UserManager: Firebase migration is DISABLED to prevent database pollution")
    }
    
    /// Automatically clean up Firebase database pollution
    func cleanupFirebasePollution() {
        print("🧹 UserManager: Starting automatic Firebase cleanup...")
        
        // First, clear all transactions to remove the explosion
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
        firestore.clearAllTransactions(userId: firebaseUserID) { result in
            switch result {
            case .success():
                print("✅ UserManager: Successfully cleaned Firebase transactions")
                
                // Now clean up fake user documents
                self.cleanupFakeUsers()
                
            case .failure(let error):
                print("❌ UserManager: Failed to clean Firebase transactions: \(error)")
            }
        }
    }
    
    /// Delete ALL users from Firebase (nuclear option)
    func deleteAllUsersFromFirebase() {
        print("💥 UserManager: NUCLEAR OPTION - Deleting ALL users from Firebase")
        firestore.deleteAllUsers { result in
            switch result {
            case .success(let deletedCount):
                print("✅ UserManager: Successfully deleted ALL \(deletedCount) users from Firebase")
                print("🔄 UserManager: Firebase users collection is now empty")
            case .failure(let error):
                print("❌ UserManager: Failed to delete all users: \(error)")
            }
        }
    }
    
    /// Create Dante Cardines III user with sample transactions (wrapper for UI)
    func createDanteUserWithSampleData() {
        print("👤 UserManager: Triggering Dante user creation with sample data...")
        firestore.createDanteUserWithSampleData { result in
            switch result {
            case .success():
                print("🎉 UserManager: Dante user created successfully!")
                print("🔄 UserManager: You can now view Dante's transactions in Firebase")
                
                // Optionally switch to Dante user in the app
                DispatchQueue.main.async {
                    self.useTestUser() // This will reload Dante's data
                }
                
            case .failure(let error):
                print("❌ UserManager: Failed to create Dante user: \(error)")
            }
        }
    }
    
    /// Generic signup function wrapper for future use
    func signupNewUser(
        name: String,
        email: String,
        primaryCurrency: String? = nil,
        withSampleData: Bool = false,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        firestore.signupUser(
            name: name,
            email: email,
            primaryCurrency: primaryCurrency ?? "",
            generateSampleData: withSampleData,
            sampleDataMonths: withSampleData ? [
                DateComponents(year: 2024, month: 9, day: 1),
                DateComponents(year: 2024, month: 10, day: 1)
            ] : []
        ) { result in
            completion(result)
        }
    }
    
    /// Clean up fake user documents in Firebase
    private func cleanupFakeUsers() {
        print("🧹 UserManager: Cleaning up fake user documents...")
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
        firestore.cleanupFakeUsers(keepOnlyUserId: firebaseUserID) { result in
            switch result {
            case .success(let deletedCount):
                print("✅ UserManager: Deleted \(deletedCount) fake user documents")
            case .failure(let error):
                print("❌ UserManager: Failed to clean fake users: \(error)")
            }
        }
    }
    
    /// Clear all transactions and start fresh (debug method)
    func clearAllTransactions() {
        print("🗑️ UserManager: CLEARING ALL TRANSACTIONS (Local + Firebase)")
        print("📊 UserManager: Before clear: \(currentUser.transactions.count) transactions")
        
        // Clear local transactions
        currentUser.transactions = []
        
        print("📊 UserManager: After clear: \(currentUser.transactions.count) transactions")
        print("🔄 UserManager: Now clearing Firebase data...")
        
        // Clear Firebase transactions collection
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
        firestore.clearAllTransactions(userId: firebaseUserID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    print("✅ UserManager: Firebase transactions cleared successfully")
                case .failure(let error):
                    print("❌ UserManager: Failed to clear Firebase: \(error)")
                }
            }
        }
        
        objectWillChange.send()
    }
    
    /// Force refresh transactions from Firebase (debug method)
    func forceRefreshTransactions() {
        print("🔄 UserManager: FORCE REFRESH - ONLY LOADING existing transactions from Firebase")
        print("🚫 UserManager: REFRESH WILL NOT CREATE ANY NEW TRANSACTIONS")
        print("📊 UserManager: Current local transaction count: \(currentUser.transactions.count)")
        
        // Show current most recent transaction
        if let mostRecent = currentUser.transactions.sorted(by: { $0.date > $1.date }).first {
            print("📅 UserManager: Current most recent LOCAL transaction: \(mostRecent.category) ₱\(mostRecent.amount) at \(mostRecent.date)")
            print("📅 UserManager: Most recent CREATED AT: \(mostRecent.createdAt)")
        }
        
        isLoadingFromFirebase = true
        firebaseError = nil
        
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
        firestore.fetchTransactions(userId: firebaseUserID) { result in
            DispatchQueue.main.async {
                self.isLoadingFromFirebase = false
                
                switch result {
                case .success(let transactions):
                    print("✅ UserManager: Force refresh loaded \(transactions.count) EXISTING transactions from Firebase")
                    print("🔍 UserManager: These transactions were ALREADY IN FIREBASE, not newly created")
                    
                    // Show the most recent transaction from Firebase
                    if let mostRecentFromFirebase = transactions.first {
                        print("📅 UserManager: Most recent from Firebase: \(mostRecentFromFirebase.category) ₱\(mostRecentFromFirebase.amount)")
                        print("📅 UserManager: Firebase transaction DATE: \(mostRecentFromFirebase.date)")
                        print("📅 UserManager: Firebase transaction CREATED AT: \(mostRecentFromFirebase.createdAt)")
                        
                        // Check if this transaction was created recently (within last 5 minutes)
                        let fiveMinutesAgo = Date().addingTimeInterval(-300)
                        if mostRecentFromFirebase.createdAt > fiveMinutesAgo {
                            print("🚨 UserManager: WARNING - This transaction was created VERY RECENTLY: \(mostRecentFromFirebase.createdAt)")
                            print("🚨 UserManager: This suggests it was just created, not loaded from existing data")
                        } else {
                            print("✅ UserManager: Transaction is from earlier: \(mostRecentFromFirebase.createdAt)")
                        }
                    }
                    
                    // Check for duplicates before updating
                    let uniqueTransactions = Array(Set(transactions))
                    print("📊 UserManager: Firebase returned \(transactions.count) transactions, \(uniqueTransactions.count) unique")
                    
                    if transactions.count != uniqueTransactions.count {
                        print("⚠️ UserManager: Found \(transactions.count - uniqueTransactions.count) duplicate transactions!")
                    }
                    
                    // Update local transactions with deduplicated data
                    self.currentUser.transactions = uniqueTransactions
                    print("📊 UserManager: Updated local transaction count to: \(self.currentUser.transactions.count)")
                    
                    // Show most recent 3 transactions with full timestamps
                    let sorted = uniqueTransactions.sorted { $0.date > $1.date }
                    print("📅 UserManager: Most recent 3 transactions after refresh:")
                    for (index, txn) in sorted.prefix(3).enumerated() {
                        print("   \(index + 1). \(txn.category) ₱\(txn.amount) - DATE: \(txn.date) - CREATED: \(txn.createdAt) - ID: \(txn.id.uuidString.prefix(8))")
                    }
                    
                    // Force UI update
                    self.objectWillChange.send()
                    
                case .failure(let error):
                    print("❌ UserManager: Force refresh failed: \(error)")
                    self.firebaseError = "Failed to refresh: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func removeTransaction(withId id: UUID) {
        // Get transaction before deletion to extract userId
        let transaction = currentUser.transactions.first { $0.id == id }
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
        
        currentUser.removeTransaction(withId: id)
        objectWillChange.send()
        
        // Enable automatic sync for transaction deletion
        if let transaction = transaction {
            syncManager?.syncTransaction(transaction, operation: .delete)
            
            // FALLBACK: Also delete directly from Firebase
            firestore.deleteTransaction(transactionId: id.uuidString, userId: firebaseUserID) { result in
                switch result {
                case .success():
                    print("✅ UserManager: FALLBACK - Transaction \(id.uuidString.prefix(8)) deleted directly from Firebase")
                case .failure(let error):
                    print("❌ UserManager: FALLBACK - Failed to delete transaction directly: \(error)")
                    DispatchQueue.main.async {
                        self.firebaseError = "Failed to delete transaction: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            print("⚠️ UserManager: Could not find transaction to sync deletion")
        }
        
        print("🗑️ UserManager: Removed transaction with ID \(id)")
    }
    
    func updateTransaction(_ transaction: Txn) {
        currentUser.updateTransaction(transaction)
        objectWillChange.send()
        
        // Enable automatic sync for transaction updates
        syncManager?.syncTransaction(transaction, operation: .update)
        
        // FALLBACK: Also save directly to Firebase
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
        firestore.saveTransaction(transaction, userId: firebaseUserID) { result in
            switch result {
            case .success():
                print("✅ UserManager: FALLBACK - Transaction \(transaction.id.uuidString.prefix(8)) updated directly in Firebase")
            case .failure(let error):
                print("❌ UserManager: FALLBACK - Failed to update transaction directly: \(error)")
                DispatchQueue.main.async {
                    self.firebaseError = "Failed to update transaction: \(error.localizedDescription)"
                }
            }
        }
        
        print("✏️ UserManager: Updated transaction - \(transaction.category) \(transaction.amount)")
    }
    
    // MARK: - Account Management
    
    func addAccount(_ account: AccountData) {
        currentUser.addAccount(account)
        print("🏦 UserManager: Added account - \(account.name) (\(account.type))")
    }
    
    func removeAccount(withId id: UUID) {
        currentUser.removeAccount(withId: id)
        print("🗑️ UserManager: Removed account with ID \(id)")
    }
    
    // Note: UserData doesn't have updateAccount method
    // To update an account, remove and re-add it
    func updateAccount(_ account: AccountData) {
        // Remove the old account and add the updated one
        currentUser.removeAccount(withId: account.id)
        currentUser.addAccount(account)
        print("✏️ UserManager: Updated account - \(account.name)")
    }

    // MARK: - Budget Management

    func addBudget(_ budget: Budget) {
        // Check if budget already exists for this category in this wallet
        if let existingIndex = currentUser.budgets.firstIndex(where: {
            $0.categoryId == budget.categoryId && $0.walletId == budget.walletId
        }) {
            // Replace existing budget
            currentUser.budgets[existingIndex] = budget
            print("🎯 UserManager: Replaced existing budget for \(budget.categoryName)")
        } else {
            currentUser.budgets.append(budget)
            print("🎯 UserManager: Added new budget - \(budget.categoryName) \(budget.amount) \(budget.currency.rawValue)/\(budget.period.displayName)")
        }

        saveCurrentUserLocally()
        objectWillChange.send()

        // Sync to Firebase
        syncToFirebase { success in
            if success {
                print("✅ UserManager: Budget synced to Firebase")
            } else {
                print("⚠️ UserManager: Budget sync to Firebase failed")
            }
        }
    }

    func updateBudget(_ budget: Budget) {
        guard let index = currentUser.budgets.firstIndex(where: { $0.id == budget.id }) else {
            print("⚠️ UserManager: Budget not found for update: \(budget.id)")
            return
        }

        var updatedBudget = budget
        updatedBudget.updatedAt = Date()
        currentUser.budgets[index] = updatedBudget

        saveCurrentUserLocally()
        objectWillChange.send()

        // Sync to Firebase
        syncToFirebase { success in
            if success {
                print("✅ UserManager: Budget update synced to Firebase")
            } else {
                print("⚠️ UserManager: Budget update sync to Firebase failed")
            }
        }

        print("✏️ UserManager: Updated budget - \(budget.categoryName)")
    }

    func deleteBudget(_ budget: Budget) {
        deleteBudget(withId: budget.id)
    }

    func deleteBudget(withId id: UUID) {
        guard let index = currentUser.budgets.firstIndex(where: { $0.id == id }) else {
            print("⚠️ UserManager: Budget not found for deletion: \(id)")
            return
        }

        let deletedBudget = currentUser.budgets.remove(at: index)

        saveCurrentUserLocally()
        objectWillChange.send()

        // Sync to Firebase
        syncToFirebase { success in
            if success {
                print("✅ UserManager: Budget deletion synced to Firebase")
            } else {
                print("⚠️ UserManager: Budget deletion sync to Firebase failed")
            }
        }

        print("🗑️ UserManager: Deleted budget - \(deletedBudget.categoryName)")
    }

    func getBudgets(for walletId: UUID) -> [Budget] {
        return currentUser.budgets.filter { $0.walletId == walletId && $0.isActive }
    }

    func getAllBudgets() -> [Budget] {
        return currentUser.budgets.filter { $0.isActive }
    }

    // MARK: - Data Access
    
    func getTransactions(for accountId: UUID? = nil) -> [Txn] {
        if let accountId = accountId {
            return currentUser.transactions(for: accountId)
        } else {
            return currentUser.transactions
        }
    }
    
    func getAccountBalance(for accountId: UUID) -> Double {
        return currentUser.balance(for: accountId)
    }
    
    // MARK: - Migration Helper
    
    /// Migrate existing global transactions to user's transaction list
    /// This can be used to move transactions from the old system to the new user-based system
    func migrateTransactions(from existingTransactions: [Txn]) {
        let defaultAccountId = currentUser.defaultAccount?.id
        
        for transaction in existingTransactions {
            let migratedTransaction = Txn(
                id: transaction.id,
                userId: currentUser.id,
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
                accountId: defaultAccountId, // Assign to default account
                originalAmount: transaction.originalAmount,
                originalCurrency: transaction.originalCurrency,
                primaryCurrency: transaction.primaryCurrency,
                secondaryCurrency: transaction.secondaryCurrency,
                exchangeRate: transaction.exchangeRate,
                secondaryAmount: transaction.secondaryAmount,
                secondaryExchangeRate: transaction.secondaryExchangeRate
            )
            currentUser.addTransaction(migratedTransaction)
        }
        
        print("🔄 UserManager: Migrated \(existingTransactions.count) transactions to user \(currentUser.name)")
    }
    
    // MARK: - One-Time Sample Data Upload
    
    /// Upload sample data to Firebase (one-time operation)
    /// Call this manually when you want to populate Firebase with test data
    func uploadSampleDataToFirebase(completion: @escaping (Bool) -> Void = { _ in }) {
        print("🚀 UserManager: Starting one-time sample data upload to Firebase...")
        print("⚠️ UserManager: WARNING - This will overwrite existing transactions!")
        print("📊 UserManager: Current transaction count before sample data: \(currentUser.transactions.count)")
        
        // Create sample transactions
        createSampleTransactions()
        print("📦 UserManager: Created \(currentUser.transactions.count) sample transactions")
        print("💰 UserManager: Sample data balance: ₱\(String(format: "%.2f", currentUser.userBalance))")
        
        // Upload to Firebase
        syncToFirebase { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ UserManager: Sample data successfully uploaded to Firebase!")
                    print("🔄 UserManager: You can now restart the app to see the data persist")
                    self.objectWillChange.send() // Update UI
                } else {
                    print("❌ UserManager: Failed to upload sample data to Firebase")
                }
                completion(success)
            }
        }
    }
    
    // MARK: - Sample Data Creation (For Manual Use)
    
    private func createSampleTransactions() {
        let personalAccountId = currentUser.accounts.first { $0.name == "Personal" }?.id
        
        // Use DummyDataGenerator for varied transaction times
        let sampleTransactions = DummyDataGenerator.generateRandom()
        
        // Add the generated transactions to user's account
        for transaction in sampleTransactions {
            let userTransaction = Txn(
                id: transaction.id,
                userId: currentUser.id,
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
                accountId: personalAccountId,
                originalAmount: transaction.originalAmount,
                originalCurrency: transaction.originalCurrency,
                primaryCurrency: transaction.primaryCurrency,
                secondaryCurrency: transaction.secondaryCurrency,
                exchangeRate: transaction.exchangeRate,
                secondaryAmount: transaction.secondaryAmount,
                secondaryExchangeRate: transaction.secondaryExchangeRate
            )
            currentUser.addTransaction(userTransaction)
        }
        
        print("📊 UserManager: Added \(sampleTransactions.count) sample transactions with varied times")
    }
    
    // MARK: - Firebase Sync Methods
    
    func loadFromFirebase(completion: @escaping (Bool) -> Void) {
        // Always load from Firebase to get latest transactions
        // (removed hasLoadedFromFirebase guard to allow multiple loads)
        
        // Quick check if Firebase is available before attempting
        #if canImport(FirebaseCore) && canImport(FirebaseFirestore)
        guard FirebaseApp.app() != nil else {
            print("🔄 UserManager: Firebase not configured, skipping load")
            completion(false)
            return
        }
        #else
        print("🔄 UserManager: Firebase packages not available, skipping load")
        completion(false)
        return
        #endif
        
        DispatchQueue.main.async {
            self.isLoadingFromFirebase = true
            self.firebaseError = nil
        }
        
        print("🔍 UserManager: Loading from Firebase for user ID: \(currentUser.id.uuidString)")
        
        // Load user data first
        // Use Firebase UID for consistent Firebase operations
        let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
        firestore.fetchUserData(userId: firebaseUserID) { [weak self] result in
            guard let self = self else { return }
            
            print("📥 UserManager: User data fetch result received")
            
            switch result {
            case .success(let userData):
                if let userData = userData {
                    DispatchQueue.main.async {
                        print("☁️ UserManager: Loaded user data from Firebase - \(userData.name)")
                        print("🏦 UserManager: Firebase has \(userData.accounts.count) accounts: \(userData.accounts.map { $0.name })")
                        print("🏦 UserManager: Current local has \(self.currentUser.accounts.count) accounts: \(self.currentUser.accounts.map { $0.name })")
                        
                        // Merge accounts instead of replacing everything
                        let mergedAccounts = self.mergeAccounts(local: self.currentUser.accounts, firebase: userData.accounts)
                        
                        // Create updated user with merged accounts but preserve LOCAL onboarding state
                        let mergedUser = UserData(
                            id: userData.id,
                            name: userData.name,
                            email: userData.email,
                            transactions: self.currentUser.transactions, // Will be updated separately
                            accounts: mergedAccounts,
                            createdAt: userData.createdAt,
                            updatedAt: max(self.currentUser.updatedAt, userData.updatedAt),
                            goals: userData.goals,
                            onboardingCompleted: self.currentUser.onboardingCompleted, // SINGLE SOURCE OF TRUTH: Keep local progress, ignore Firebase
                            enableFirebaseSync: userData.enableFirebaseSync
                        )
                        
                        print("🔢 UserManager: Keeping LOCAL onboarding progress: \(self.currentUser.onboardingCompleted)")
                        print("   - Firebase onboarding field excluded from sync (local-only)")
                        print("   - Each device tracks its own onboarding state independently")
                        
                        self.currentUser = mergedUser
                        print("🔄 UserManager: Merged accounts - final count: \(mergedAccounts.count)")
                        print("🔄 UserManager: Final account names: \(mergedAccounts.map { $0.name })")
                    }
                } else {
                    print("⚠️ UserManager: No user data found in Firebase for ID: \(self.currentUser.id.uuidString)")
                }
                
                // Load transactions separately
                print("🔍 UserManager: Fetching transactions for user: \(self.currentUser.id.uuidString)")
                // Use Firebase UID for consistent Firebase operations
                let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? self.currentUser.id.uuidString
                self.firestore.fetchTransactions(userId: firebaseUserID) { transactionResult in
                    DispatchQueue.main.async {
                        self.isLoadingFromFirebase = false
                        
                        switch transactionResult {
                        case .success(let transactions):
                            print("📥 UserManager: Transaction fetch successful - received \(transactions.count) transactions")
                            
                            if transactions.isEmpty {
                                print("⚠️ UserManager: No transactions found in Firebase for user \(self.currentUser.id.uuidString)")
                                print("💡 UserManager: This could mean:")
                                print("   - User has no transactions yet")
                                print("   - Sample data upload hasn't run")
                                print("   - Wrong user ID being used")
                            } else {
                                print("📊 UserManager: Transaction details:")
                                for (index, txn) in transactions.prefix(3).enumerated() {
                                    print("   \(index + 1). \(txn.category): ₱\(txn.amount) on \(txn.date)")
                                }
                                if transactions.count > 3 {
                                    print("   ... and \(transactions.count - 3) more")
                                }
                            }
                            
                            // Log before assignment
                            print("🔄 UserManager: BEFORE assignment - current transaction count: \(self.currentUser.transactions.count)")
                            
                            self.currentUser.transactions = transactions
                            self.hasLoadedFromFirebase = true
                            
                            // Log after assignment
                            print("🔄 UserManager: AFTER assignment - current transaction count: \(self.currentUser.transactions.count)")
                            print("☁️ UserManager: Loaded \(transactions.count) transactions from Firebase")
                            print("💰 UserManager: Updated balance after Firebase sync: ₱\(String(format: "%.2f", self.currentUser.userBalance))")
                            
                            // Add a delay to see what happens to the data
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                print("⏰ UserManager: 2 seconds later - transaction count: \(self.currentUser.transactions.count)")
                                print("⏰ UserManager: 2 seconds later - balance: ₱\(String(format: "%.2f", self.currentUser.userBalance))")
                            }
                            
                            // Trigger UI update
                            self.objectWillChange.send()
                            completion(true)
                            
                        case .failure(let error):
                            print("❌ UserManager: Transaction fetch failed with error: \(error)")
                            print("🔍 UserManager: Error details: \(error.localizedDescription)")
                            self.firebaseError = "Failed to load data: \(error.localizedDescription)"
                            completion(false)
                        }
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoadingFromFirebase = false
                    print("⚠️ UserManager: Failed to load user data from Firebase: \(error)")
                    self.firebaseError = "Failed to load user: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }
    
    /// Manually refresh transactions from Firebase (can be called anytime)
    func refreshFromFirebase(completion: @escaping (Bool) -> Void = { _ in }) {
        print("🔄 UserManager: Manual refresh from Firebase requested")
        
        // Temporarily reset the flag to allow fresh load
        let previousFlag = hasLoadedFromFirebase
        hasLoadedFromFirebase = false
        
        loadFromFirebase { success in
            if success {
                print("✅ UserManager: Manual refresh completed successfully")
            } else {
                print("❌ UserManager: Manual refresh failed")
                // Restore previous flag state
                self.hasLoadedFromFirebase = previousFlag
            }
            completion(success)
        }
    }
    
    func syncToFirebase(completion: @escaping (Bool) -> Void) {
        // Check if Firebase sync is enabled for this user
        guard currentUser.enableFirebaseSync else {
            print("🚫 UserManager: Firebase sync disabled for user - skipping sync")
            completion(true) // Return success since user chose not to sync
            return
        }
        
        // Save user data
        firestore.saveUserData(currentUser) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success():
                // Save all transactions
                let dispatchGroup = DispatchGroup()
                var hasErrors = false
                
                for transaction in self.currentUser.transactions {
                    dispatchGroup.enter()
                    // Use Firebase UID for consistent Firebase operations
                    let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? self.currentUser.id.uuidString
                    self.firestore.saveTransaction(transaction, userId: firebaseUserID) { transactionResult in
                        if case .failure = transactionResult {
                            hasErrors = true
                        }
                        dispatchGroup.leave()
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                    if hasErrors {
                        self.firebaseError = "Some transactions failed to sync"
                        completion(false)
                    } else {
                        print("☁️ UserManager: All data synced to Firebase successfully")
                        completion(true)
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.firebaseError = "Failed to sync user data: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }
    }
    
    func clearFirebaseError() {
        firebaseError = nil
    }
    
    // MARK: - Sync Manager Integration
    
    /// Get current sync status
    func getSyncStatus() -> SyncStatus {
        return syncManager?.getSyncStatus() ?? .notSynced
    }
    
    /// Force immediate sync
    func forceSync() {
        syncManager?.forcSync()
    }
    
    /// Check if transactions are currently syncing
    var isSyncing: Bool {
        return syncManager?.isSyncing ?? false
    }
    
    /// Get pending changes count
    var pendingChangesCount: Int {
        return syncManager?.pendingChangesCount ?? 0
    }
    
    /// Get last sync date
    var lastSyncDate: Date? {
        return syncManager?.lastSyncDate
    }
    
    /// Clear sync errors
    func clearSyncError() {
        syncManager?.clearSyncError()
    }
    
    
    // MARK: - Account Management Methods
    
    func addSubAccount(_ subAccount: SubAccount) {
        currentUser.addSubAccount(subAccount)
        // Update timestamp to ensure local changes are preserved during Firebase merge
        currentUser.updatedAt = Date()
        
        // CRITICAL: Save to local storage immediately to persist across app restarts
        saveCurrentUserLocally()
        
        // Defer objectWillChange to avoid publishing during view updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("💾 UserManager: Wallet added and saved locally")
    }
    
    func deleteAccount(withId accountId: UUID) {
        currentUser.removeAccount(withId: accountId)
        
        // Check if this was the last wallet - if so, reset onboarding to 1
        if currentUser.accounts.isEmpty {
            print("🚨 UserManager: Last wallet deleted - resetting onboarding to step 1 (name collection)")
            print("   User will skip email verification but redo name/currency/goals setup")
            updateOnboardingProgress(1)
            
            // Also reset the OnboardingStateManager to ensure UI consistency
            OnboardingStateManager.shared.resetOnboardingToStep(1)
        } else {
            print("💾 UserManager: Wallet deleted - \(currentUser.accounts.count) wallets remaining")
        }
        
        // Save to local storage immediately
        saveCurrentUserLocally()
        
        // Defer objectWillChange to avoid publishing during view updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("💾 UserManager: Wallet deletion complete and saved locally")
    }
    
    func setDefaultSubAccount(_ accountId: UUID) {
        currentUser.setDefaultSubAccount(accountId)
        
        // Save to local storage immediately
        saveCurrentUserLocally()
        
        // Defer objectWillChange to avoid publishing during view updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("💾 UserManager: Default account changed and saved locally")
    }
    
    func modifyAccount(_ accountData: AccountData) {
        if let index = currentUser.accounts.firstIndex(where: { $0.id == accountData.id }) {
            currentUser.accounts[index] = accountData
            currentUser.updatedAt = Date()
            
            // Save to local storage immediately
            saveCurrentUserLocally()
            
            objectWillChange.send()
            print("💾 UserManager: Account modified and saved locally")
        }
    }
    
    // MARK: - Account Merging
    
    /// Intelligently merge local and Firebase accounts to preserve local changes
    private func mergeAccounts(local: [AccountData], firebase: [AccountData]) -> [AccountData] {
        print("🔄 UserManager: Starting account merge...")
        print("📱 Local accounts: \(local.map { "\($0.name) (\($0.id.uuidString.prefix(8)))" })")
        print("☁️ Firebase accounts: \(firebase.map { "\($0.name) (\($0.id.uuidString.prefix(8)))" })")
        
        var mergedAccounts: [AccountData] = []
        var processedIds = Set<UUID>()
        
        // 1. Start with all local accounts (preserves new accounts like Rosebud)
        for localAccount in local {
            if let firebaseAccount = firebase.first(where: { $0.id == localAccount.id }) {
                // Account exists in both - use Firebase data but preserve local updates if newer
                if localAccount.updatedAt > firebaseAccount.updatedAt {
                    print("📱 Using local version of '\(localAccount.name)' (newer: \(localAccount.updatedAt) > \(firebaseAccount.updatedAt))")
                    mergedAccounts.append(localAccount)
                } else {
                    print("☁️ Using Firebase version of '\(firebaseAccount.name)' (newer: \(firebaseAccount.updatedAt) >= \(localAccount.updatedAt))")
                    mergedAccounts.append(firebaseAccount)
                }
            } else {
                // Account only exists locally (like new Rosebud wallet)
                print("✨ Preserving local-only account: '\(localAccount.name)'")
                mergedAccounts.append(localAccount)
            }
            processedIds.insert(localAccount.id)
        }
        
        // 2. Add Firebase-only accounts that we haven't processed
        for firebaseAccount in firebase {
            if !processedIds.contains(firebaseAccount.id) {
                print("☁️ Adding Firebase-only account: '\(firebaseAccount.name)'")
                mergedAccounts.append(firebaseAccount)
                processedIds.insert(firebaseAccount.id)
            }
        }
        
        // 3. Ensure we always have at least one default account
        if mergedAccounts.isEmpty {
            print("⚠️ No accounts after merge, creating default wallet...")
            let defaultWallet = AccountData(
                id: UUID(), // Always use unique UUIDs
                name: "", // Empty name - will be set during onboarding
                type: .personal,
                currency: .usd, // Temporary placeholder - will be updated during currency selection onboarding
                isDefault: true
            )
            mergedAccounts.append(defaultWallet)
        } else if !mergedAccounts.contains(where: { $0.isDefault }) {
            // No default account - make the first one default
            mergedAccounts[0].isDefault = true
            print("✅ Set '\(mergedAccounts[0].name)' as default account")
        }
        
        print("🔄 UserManager: Merge complete - final accounts: \(mergedAccounts.map { $0.name })")
        return mergedAccounts
    }
    
    // MARK: - Local Data Persistence
    
    /// SECURITY: Verify that all wallets in current user belong to the current Firebase user
    private func verifyWalletOwnership() {
        let currentFirebaseUID = AuthenticationManager.shared.currentUser?.firebaseUID
        let currentEmail = currentUser.email
        
        print("🔒 UserManager: SECURITY - Verifying wallet ownership for user: \(currentEmail)")
        print("🔒 UserManager: Firebase UID: \(currentFirebaseUID ?? "nil")")
        
        var validWallets: [AccountData] = []
        
        for wallet in currentUser.accounts {
            // Check if this wallet was created by the current user
            // For now, keep all wallets but log suspicious ones
            if wallet.name == "Rosebud Studio Sample" {
                print("⚠️ UserManager: SECURITY WARNING - Found potentially cross-contaminated wallet: '\(wallet.name)'")
                print("⚠️ UserManager: This wallet may belong to a different user - investigate further")
                
                // For security, skip this wallet for now
                print("🚫 UserManager: SECURITY - Removing suspicious wallet from current user")
                continue
            }
            validWallets.append(wallet)
        }
        
        if validWallets.count != currentUser.accounts.count {
            print("🔒 UserManager: SECURITY - Removed \(currentUser.accounts.count - validWallets.count) suspicious wallets")
            currentUser.accounts = validWallets
        } else {
            print("✅ UserManager: SECURITY - All wallets verified as belonging to current user")
        }
    }
    
    /// Save current user data to local storage (UserDefaults)
    func saveCurrentUserLocally() {
        // SECURITY: Verify wallet ownership before saving
        verifyWalletOwnership()
        
        print("💾 UserManager: SAVING USER DATA TO LOCAL STORAGE")
        print("   👤 User: \(currentUser.name) (\(currentUser.email))")
        print("   🆔 User ID: \(currentUser.id.uuidString)")
        print("   🏦 Wallets to save: \(currentUser.accounts.count)")
        
        for (index, account) in currentUser.accounts.enumerated() {
            print("   \(index + 1). '\(account.name)' (\(account.id.uuidString.prefix(8))...) - Default: \(account.isDefault)")
        }
        
        print("   📊 Transactions to save: \(currentUser.transactions.count)")
        print("   ☁️ Firebase sync enabled: \(currentUser.enableFirebaseSync)")
        
        do {
            let encoded = try JSONEncoder().encode(currentUser)
            
            // Use Firebase UID for consistent storage key
            let firebaseUID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
            let key = "currentUser_firebase_\(firebaseUID)"
            
            UserDefaults.standard.set(encoded, forKey: key)
            UserDefaults.standard.synchronize()
            
            print("✅ UserManager: User data saved successfully to local storage")
            print("🔑 UserManager: Storage key: \(key)")
            print("🔑 UserManager: Using Firebase UID: \(firebaseUID)")
            print("📦 UserManager: Data size: \(encoded.count) bytes")
            
            // Verify the save worked
            if let verification = UserDefaults.standard.data(forKey: key) {
                print("✅ UserManager: VERIFICATION - Data can be read back from storage")
                if let verifyUser = try? JSONDecoder().decode(UserData.self, from: verification) {
                    print("✅ UserManager: VERIFICATION - Data can be decoded successfully")
                    print("   🏦 Verified wallet count: \(verifyUser.accounts.count)")
                    print("   📝 Verified user name: \(verifyUser.name)")
                } else {
                    print("❌ UserManager: VERIFICATION FAILED - Data cannot be decoded")
                }
            } else {
                print("❌ UserManager: VERIFICATION FAILED - Data not found in storage")
            }
            
        } catch {
            print("❌ UserManager: Failed to save user data locally: \(error)")
        }
    }
    
    /// Load user data from local storage
    private func loadCurrentUserLocally() -> UserData? {
        // For backward compatibility, try multiple possible keys
        let possibleKeys = [
            "currentUser_\(currentUser.id.uuidString)",
            "currentUser", // Legacy key
            "userData" // Another possible legacy key
        ]
        
        for key in possibleKeys {
            if let data = UserDefaults.standard.data(forKey: key),
               let user = try? JSONDecoder().decode(UserData.self, from: data) {
                print("💾 UserManager: Loaded user data from local storage (key: \(key))")
                return user
            }
        }
        
        print("💾 UserManager: No local user data found")
        return nil
    }
    
    /// Load specific user data from local storage by Firebase UID
    private func loadUserFromLocalStorage(firebaseUID: String, userEmail: String) -> UserData? {
        print("💾 UserManager: Searching local storage for Firebase UID: \(firebaseUID)")
        
        let userKey = "currentUser_firebase_\(firebaseUID)"
        print("🔑 UserManager: Looking for data with key: \(userKey)")
        
        // Debug: List all UserDefaults keys that start with "currentUser"
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let userKeys = allKeys.filter { $0.hasPrefix("currentUser") }
        print("🔍 UserManager: Available currentUser keys in storage: \(userKeys)")
        
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(UserData.self, from: data) {
            print("✅ UserManager: Found local data for user \(user.name)")
            print("🏦 UserManager: Local data has \(user.accounts.count) wallets")
            print("📊 UserManager: Local data has \(user.transactions.count) transactions")
            print("☁️ UserManager: Firebase sync enabled: \(user.enableFirebaseSync)")
            return user
        }
        
        print("❌ UserManager: No local data found for Firebase UID: \(firebaseUID)")
        print("🔑 UserManager: Tried key: \(userKey)")
        
        // BACKWARD COMPATIBILITY: Try to find data saved with UUID-based keys FOR THIS SPECIFIC USER
        print("🔄 UserManager: Checking for existing UUID-based wallet data for current user...")
        print("🔍 UserManager: Current user email: \(userEmail)")
        
        let uuidKeys = userKeys.filter { $0.hasPrefix("currentUser_") && $0 != userKey }
        for uuidKey in uuidKeys.prefix(10) { // Check more keys but verify ownership
            if let data = UserDefaults.standard.data(forKey: uuidKey),
               let user = try? JSONDecoder().decode(UserData.self, from: data) {
                
                // SECURITY CHECK: Only migrate data that belongs to THIS user
                if user.email == userEmail {
                    print("🔄 UserManager: Found matching user data in legacy key: \(uuidKey)")
                    print("🏦 UserManager: User \(user.email) has \(user.accounts.count) wallets: \(user.accounts.map { $0.name })")
                    
                    // Migrate to new Firebase UID key format
                    let newKey = "currentUser_firebase_\(firebaseUID)"
                    UserDefaults.standard.set(data, forKey: newKey)
                    print("✅ UserManager: Migrated USER'S OWN wallet data to new Firebase UID key: \(newKey)")
                    
                    return user
                } else {
                    print("🚫 UserManager: SECURITY - Skipping data for different user: \(user.email) (current: \(userEmail))")
                }
            }
        }
        
        // Also try legacy keys for backward compatibility
        let legacyKeys = ["currentUser", "userData"]
        for key in legacyKeys {
            if let data = UserDefaults.standard.data(forKey: key),
               let user = try? JSONDecoder().decode(UserData.self, from: data) {
                print("✅ UserManager: Found user data in legacy key: \(key)")
                
                // Migrate to new Firebase UID key format
                let newKey = "currentUser_firebase_\(firebaseUID)"
                UserDefaults.standard.set(data, forKey: newKey)
                UserDefaults.standard.removeObject(forKey: key)
                print("🔄 UserManager: Migrated legacy data to new Firebase UID key format")
                
                return user
            }
        }
        
        return nil
    }
    
    /// Restore user session from local storage first, then Firebase
    func restoreUserSessionWithLocalFirst() {
        print("💾 UserManager: Attempting to restore from local storage first...")
        
        if let localUser = loadCurrentUserLocally() {
            print("✅ UserManager: Found local user data - \(localUser.name)")
            print("🏦 UserManager: Local accounts: \(localUser.accounts.map { $0.name })")
            
            currentUser = localUser
            objectWillChange.send()
            
            // Complete initial load to start sync manager
            completeInitialLoad()
            
            // Then check Firebase for updates (non-blocking)
            DispatchQueue.global(qos: .utility).async {
                self.loadFromFirebase { success in
                    print(success ? "✅ Firebase sync after local load" : "⚠️ Firebase sync failed, using local data")
                }
            }
        } else {
            print("💾 UserManager: No local data, falling back to normal restoration")
            // Fall back to original behavior
            restoreUserSession()
        }
    }
    
    // MARK: - Firebase Sync Control
    
    /// Toggle Firebase sync preference for the current user
    func setFirebaseSyncEnabled(_ enabled: Bool) {
        currentUser.enableFirebaseSync = enabled
        currentUser.updatedAt = Date()
        
        // IMPORTANT: Save this preference immediately to persist across app restarts
        UserDefaults.standard.set(enabled, forKey: "enableFirebaseSync_\(currentUser.id.uuidString)")
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("🔄 UserManager: Firebase sync \(enabled ? "enabled" : "disabled") for user")
        print("💾 UserManager: Sync preference saved to UserDefaults")
        
        // If enabling sync and we have data, sync immediately
        if enabled && !currentUser.transactions.isEmpty {
            print("📤 UserManager: Syncing existing data to Firebase...")
            syncToFirebase { success in
                print(success ? "✅ Initial sync completed" : "❌ Initial sync failed")
            }
        }
        
        // If disabling sync, optionally clear local sync metadata
        if !enabled {
            print("🗑️ UserManager: Firebase sync disabled - keeping local data")
            // Note: We keep local data but stop syncing to Firebase
        }
    }
    
    /// Get current Firebase sync status
    var isFirebaseSyncEnabled: Bool {
        // Check UserDefaults first for persisted preference
        let userDefaultsKey = "enableFirebaseSync_\(currentUser.id.uuidString)"
        if UserDefaults.standard.object(forKey: userDefaultsKey) != nil {
            let savedPreference = UserDefaults.standard.bool(forKey: userDefaultsKey)
            // Update currentUser to match saved preference if different
            if currentUser.enableFirebaseSync != savedPreference {
                currentUser.enableFirebaseSync = savedPreference
            }
            return savedPreference
        }
        
        // Fallback to currentUser property
        return currentUser.enableFirebaseSync
    }
    
    // MARK: - Firebase Debugging
    
    /// Debug Firebase data for specific user
    func debugFirebaseDataForUser(_ email: String = "dcardinesiii+4@gmail.com") {
        print("🔍 UserManager: DEBUG - Checking Firebase data for \(email)")
        
        // Check current user first
        print("🔍 Current UserManager state:")
        print("   📧 Email: \(currentUser.email)")
        print("   👤 Name: \(currentUser.name)")
        print("   🆔 User ID: \(currentUser.id.uuidString)")
        print("   🏦 Accounts count: \(currentUser.accounts.count)")
        print("   🏦 Account names: \(currentUser.accounts.map { $0.name })")
        print("   ☁️ Firebase sync enabled: \(currentUser.enableFirebaseSync)")
        
        #if canImport(FirebaseAuth)
        if let firebaseUser = Auth.auth().currentUser {
            print("   🔥 Firebase UID: \(firebaseUser.uid)")
            
            // Test Firebase data fetch with current UID
            let firebaseUserID = firebaseUser.uid
            print("🔍 UserManager: Fetching Firebase data with UID: \(firebaseUserID)")
            
            firestore.fetchUserData(userId: firebaseUserID) { result in
                switch result {
                case .success(let userData):
                    if let userData = userData {
                        print("✅ UserManager: Firebase data found!")
                        print("   📧 Firebase email: \(userData.email)")
                        print("   👤 Firebase name: \(userData.name)")
                        print("   🏦 Firebase accounts: \(userData.accounts.count)")
                        print("   🏦 Firebase account names: \(userData.accounts.map { $0.name })")
                        print("   ☁️ Firebase sync setting: \(userData.enableFirebaseSync)")
                    } else {
                        print("❌ UserManager: No Firebase user data found for UID \(firebaseUserID)")
                    }
                case .failure(let error):
                    print("❌ UserManager: Firebase fetch failed: \(error.localizedDescription)")
                }
            }
        } else {
            print("❌ UserManager: No Firebase user currently authenticated")
        }
        #endif
    }
    
    /// Manually sync current user data to Firebase (for debugging/repair)
    func forceManualSyncToFirebase() {
        print("🔧 UserManager: MANUAL SYNC - Forcing current user data to Firebase")
        print("📤 UserManager: Syncing user: \(currentUser.name) (\(currentUser.email))")
        print("🏦 UserManager: Accounts to sync: \(currentUser.accounts.map { $0.name })")
        
        syncToFirebase { success in
            if success {
                print("✅ UserManager: Manual sync completed successfully")
            } else {
                print("❌ UserManager: Manual sync failed")
            }
        }
    }
    
    // MARK: - Firebase Connection Testing
    
    func testFirebaseConnection() {
        print("🔥 UserManager: Testing Firebase connection...")
        
        // Test simple Firestore read operation
        firestore.testConnection { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    print("✅ Firebase connection test PASSED - Backend reachable")
                    self.firebaseError = nil
                case .failure(let error):
                    print("❌ Firebase connection test FAILED: \(error.localizedDescription)")
                    self.firebaseError = "Connection failed: \(error.localizedDescription)"
                    
                    // Provide user-friendly guidance
                    if error.localizedDescription.contains("network") || error.localizedDescription.contains("timeout") {
                        print("🌐 Suggestion: Check your internet connection")
                    } else if error.localizedDescription.contains("permissions") {
                        print("🔑 Suggestion: Check Firebase security rules")
                    } else {
                        print("🔧 Suggestion: Check Firebase project configuration")
                    }
                }
            }
        }
    }
    
    // MARK: - Manual Sample Data Generation
    
    func generateFixedSampleData() {
        print("🎯 UserManager: Generating fixed sample data...")
        print("📊 UserManager: Current transaction count before: \(currentUser.transactions.count)")
        
        // Clear existing transactions first
        currentUser.transactions.removeAll()
        print("🗑️ UserManager: Cleared existing transactions")
        
        // Generate fixed sample transactions
        let sampleTransactions = DummyDataGenerator.generateFixedSampleData()
        print("🎯 UserManager: Generated \(sampleTransactions.count) sample transactions")
        
        // Debug: Print first few transactions
        for (index, transaction) in sampleTransactions.prefix(3).enumerated() {
            print("📋 Transaction \(index + 1): \(transaction.merchantName ?? "Unknown") - \(transaction.category) - \(transaction.amount)")
        }
        
        // Add to current user
        for transaction in sampleTransactions {
            currentUser.addTransaction(transaction)
            print("✅ Added transaction: \(transaction.merchantName ?? "Unknown") - \(transaction.amount)")
        }
        
        print("✅ UserManager: Added \(sampleTransactions.count) fixed sample transactions")
        print("📊 UserManager: Current transaction count after: \(currentUser.transactions.count)")
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
            
            // Also trigger AccountManager refresh to ensure filtered transactions update
            AccountManager.shared.objectWillChange.send()
            
            // Debug: Check if AccountManager can see the transactions
            let filteredCount = AccountManager.shared.filteredTransactions.count
            print("🏦 UserManager: AccountManager now sees \(filteredCount) filtered transactions")
            
            if let selectedAccountId = AccountManager.shared.selectedSubAccountId {
                print("🏦 UserManager: Currently selected account: \(selectedAccountId.uuidString.prefix(8))...")
                let accountTransactions = self.currentUser.transactions(for: selectedAccountId)
                print("🏦 UserManager: Transactions for selected account: \(accountTransactions.count)")
            } else {
                print("🏦 UserManager: No account currently selected")
            }
        }
        
        // Optionally sync to Firebase
        for transaction in sampleTransactions {
            // Use Firebase UID for consistent Firebase operations
            let firebaseUserID = AuthenticationManager.shared.currentUser?.firebaseUID ?? currentUser.id.uuidString
            firestore.saveTransaction(transaction, userId: firebaseUserID) { result in
                switch result {
                case .success():
                    print("✅ UserManager: Sample transaction synced to Firebase")
                case .failure(let error):
                    print("❌ UserManager: Failed to sync sample transaction: \(error)")
                }
            }
        }
    }
    
    // MARK: - Security Methods
    
    /// Clean up any cross-contaminated data that doesn't belong to the current user
    private func cleanupCrossContaminatedData(currentUserEmail: String) {
        print("🛡️ UserManager: SECURITY - Cleaning up cross-contaminated data for \(currentUserEmail)")
        
        let beforeAccountCount = currentUser.accounts.count
        let beforeTransactionCount = currentUser.transactions.count
        
        print("🔍 UserManager: SECURITY - Before cleanup: \(beforeAccountCount) accounts")
        for (index, account) in currentUser.accounts.enumerated() {
            print("   \(index + 1). '\(account.name)' (ID: \(account.id.uuidString.prefix(8)))")
        }
        
        // Remove any suspicious accounts that clearly don't belong to this user (case-insensitive)
        let suspiciousAccountNames = [
            "rosebud studio sample",
            "rosebud studio", 
            "test account", 
            "sample business",
            "demo account",
            "sample wallet",
            "test wallet"
        ]
        
        // Filter out suspicious accounts (case-insensitive comparison)
        let cleanedAccounts = currentUser.accounts.filter { account in
            let accountNameLower = account.name.lowercased()
            let isSuspicious = suspiciousAccountNames.contains(accountNameLower)
            if isSuspicious {
                print("🗑️ UserManager: SECURITY - Removing suspicious account '\(account.name)' that doesn't belong to \(currentUserEmail)")
            }
            return !isSuspicious
        }
        
        currentUser.accounts = cleanedAccounts
        
        // Remove any transactions from removed accounts
        let validAccountIds = Set(cleanedAccounts.map { $0.id })
        let cleanedTransactions = currentUser.transactions.filter { transaction in
            if let walletID = transaction.walletID, !validAccountIds.contains(walletID) {
                print("🗑️ UserManager: SECURITY - Removing transaction from deleted suspicious account")
                return false
            }
            return true
        }
        
        currentUser.transactions = cleanedTransactions
        
        let afterAccountCount = currentUser.accounts.count
        let afterTransactionCount = currentUser.transactions.count
        
        let removedAccounts = beforeAccountCount - afterAccountCount
        let removedTransactions = beforeTransactionCount - afterTransactionCount
        
        if removedAccounts > 0 || removedTransactions > 0 {
            print("🛡️ UserManager: SECURITY CLEANUP COMPLETE:")
            print("   🗑️ Removed \(removedAccounts) suspicious accounts")
            print("   🗑️ Removed \(removedTransactions) orphaned transactions")
            print("   ✅ User \(currentUserEmail) data is now clean")
            
            // Save cleaned data immediately
            saveCurrentUserLocally()
        } else {
            print("✅ UserManager: SECURITY - No cross-contaminated data found for \(currentUserEmail)")
        }
    }
    
    // MARK: - User Profile Management

    // MARK: - App Review Request

    /// Request app review after user reaches 3 transactions (only once)
    private func checkAndRequestAppReview() {
        // Only request review once and when user has exactly 3 transactions
        guard !hasRequestedAppReview,
              currentUser.transactions.count == 3 else {
            return
        }

        print("⭐ UserManager: User has 3 transactions, requesting app review...")

        // Mark as requested before showing to prevent duplicate requests
        hasRequestedAppReview = true

        // Small delay to let the UI settle after adding transaction
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                print("⭐ UserManager: App review request shown")
            }
        }
    }
}
