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

/// A local data box on this device, surfaced in the "Upload local data" picker so the
/// user can choose which one to attach to their login.
struct LocalDataBox: Identifiable, Equatable {
    let uid: String            // the currentUser_firebase_<uid> key suffix
    let name: String
    let email: String
    let transactionCount: Int
    let walletCount: Int
    let updatedAt: Date
    /// Already attached to this account. Firebase stays the source of truth; a linked box is a
    /// local MIRROR of the account's data, rewritten on every save so it never goes stale.
    let isLinked: Bool
    var id: String { uid }

    /// Compact age string ("2m ago", "3d ago") shared by the picker and the Settings status row.
    static func relativeAge(_ date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        let minute = 60.0, hour = 3_600.0, day = 86_400.0, week = 604_800.0, year = 31_536_000.0
        switch seconds {
        case ..<minute: return "just now"
        case ..<hour:   return "\(Int(seconds / minute))m ago"
        case ..<day:    return "\(Int(seconds / hour))h ago"
        case ..<week:   return "\(Int(seconds / day))d ago"
        case ..<year:   return "\(Int(seconds / week))w ago"
        default:        return "\(Int(seconds / year))y ago"
        }
    }
}

class UserManager: ObservableObject {
    static let shared = UserManager()

    @Published var currentUser: UserData
    @Published var isLoadingFromFirebase = false
    @Published var firebaseError: String?

    // Real cloud-sync status (drives the truthful "Sync to Cloud" subtitle).
    @Published var isSyncingToCloud = false
    @Published var lastCloudSyncFailed = false
    @Published var lastCloudSyncAt: Date? = {
        let t = UserDefaults.standard.double(forKey: "lastCloudSyncAt")
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }()

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
            enableFirebaseSync: true // DEFAULT ON - cloud backup so data survives reinstall
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

    // MARK: - Role assignment

    /// Emails that get the "admin" role. Everyone else is "user".
    private static let adminEmails: Set<String> = ["dcardinesiii@gmail.com"]

    /// Fills in currentUser.role after load/login. Allowlisted emails are
    /// always admins; everyone else gets "user" only when the role is unset,
    /// so a manually assigned role (profile-name tap trick) survives relaunch.
    func ensureRoleAssigned() {
        let email = currentUser.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if Self.adminEmails.contains(email) {
            guard currentUser.role != "admin" else { return }
            setRole("admin")
        } else if currentUser.role == nil {
            setRole("user")
        }
    }

    /// Sets the role explicitly and persists it (local + Firebase).
    func setRole(_ role: String) {
        currentUser.role = role
        objectWillChange.send()
        print("🛡️ UserManager: Role set to '\(role)' for \(currentUser.email)")
        saveCurrentUserLocally()
        if currentUser.enableFirebaseSync {
            syncToFirebase { success in
                print(success ? "🛡️ UserManager: Role synced to Firebase" : "⚠️ UserManager: Role sync failed")
            }
        }
    }
    
    // MARK: - User Authentication & Session Management
    
    /// Restore user session from stored data or fallback to test user
    /// LOCAL-FIRST: Always loads from local storage first, Firebase is for future sync only
    func restoreUserSession() {
        print("🔄 UserManager: RESTORE SESSION DEBUG - Starting session restoration")
        print("📱 UserManager: LOCAL-FIRST MODE - Loading from device storage")

        // STEP 1: Try to load from local storage FIRST (this is the primary data source)
        if let localUser = loadCurrentUserLocally() {
            print("✅ UserManager: LOCAL DATA FOUND - Using local storage as primary source")
            print("   👤 User: \(localUser.name)")
            print("   📧 Email: \(localUser.email)")
            print("   📊 Transactions: \(localUser.transactions.count)")
            print("   🏦 Wallets: \(localUser.accounts.count)")
            print("   🎯 Budgets: \(localUser.budgets.count)")

            // Use the locally stored user data
            self.currentUser = localUser
            ensureRoleAssigned()

            // Returning user with real data must skip onboarding + the post-onboarding paywall
            // on launch. The onboarding gate reads currentUser.onboardingCompleted, so promote it
            // when the box clearly belongs to a set-up user (transactions / default wallet / prior
            // completion flags). Without this, a box saved at < 16 shows onboarding every launch.
            checkAndMarkOnboardingComplete()

            self.objectWillChange.send()

            // Trigger AccountManager refresh
            DispatchQueue.main.async {
                AccountManager.shared.objectWillChange.send()
            }

            print("💾 UserManager: Session restored from LOCAL STORAGE")

            // Local data is source of truth. Ensure sync is ON and push a backup to cloud.
            migrateEnableSyncIfNeeded()

            // Notify that loading is complete
            NotificationCenter.default.post(name: NSNotification.Name("UserManagerFirebaseLoadComplete"), object: nil)
            return
        }

        print("💾 UserManager: No local data found - setting up user profile")

        // STEP 2: No local data - check if we have an authenticated user from Firebase Auth
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

            // CLOUD RESTORE ON EVERY SIGN-IN. Signing in means "give me my account's data",
            // so we always pull — not only when the device happens to be empty.
            //
            // This used to be gated on `currentUser.transactions.isEmpty`, which made signing in
            // a no-op for anyone whose device already held a single transaction: the account's
            // data simply never arrived. That guard existed because an older loadFromFirebase
            // REPLACED the local array and an empty/stale cloud read could wipe it. It no longer
            // replaces: mergeTransactions unions by id, honours deletion tombstones, and collapses
            // duplicate generated occurrences. A merge cannot lose local rows, so the guard's
            // reason is gone.
            //
            // Anything this device holds that the cloud lacks is pushed up right after, so the
            // two sides converge instead of drifting.
            let localBeforeRestore = Set(currentUser.transactions.map(\.id))
            print("☁️ UserManager: Sign-in cloud restore for \(authenticatedUser.email) — \(localBeforeRestore.count) local transaction(s) before merge")
            loadFromFirebase { [weak self] success in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    print(success ? "☁️ UserManager: Cloud restore complete — \(self.currentUser.transactions.count) transaction(s) after merge"
                                  : "⚠️ UserManager: Cloud restore failed — keeping local data untouched")
                    self.saveCurrentUserLocally()
                    self.objectWillChange.send()
                    NotificationCenter.default.post(name: NSNotification.Name("UserManagerFirebaseLoadComplete"), object: nil)

                    // Push up anything the cloud didn't have. Only when the restore actually
                    // succeeded — otherwise a failed read could look like "cloud is missing
                    // everything" and trigger a pointless full upload.
                    if success, !localBeforeRestore.isEmpty {
                        self.uploadTransactionsMissingFromCloud(localIDsBeforeRestore: localBeforeRestore)
                    }
                }
            }
            return
        }

        // STEP 3: No authenticated user (dev/test) - start empty locally.
        print("🔧 UserManager: No authenticated user, using test user for development")
        useTestUser()
        print("👋 UserManager: NEW USER - Starting with empty transaction list")
        print("📱 UserManager: Transactions will be stored locally on this device")
        self.currentUser.transactions = []
        self.objectWillChange.send()

        // Save the new user to local storage immediately
        saveCurrentUserLocally()

        // Notify that loading is complete
        NotificationCenter.default.post(name: NSNotification.Name("UserManagerFirebaseLoadComplete"), object: nil)
        
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
    
    /// Cloud-sync migration for users whose local data predates default-on sync.
    /// SAFE: only ever turns sync ON and PUSHES local data up. Never pulls, never
    /// overwrites local. Respects an explicit user opt-out if one was saved.
    private func migrateEnableSyncIfNeeded() {
        let explicitlyDisabled = syncOptOutIsExplicit()
        guard !explicitlyDisabled else {
            print("☁️ UserManager: User explicitly disabled sync - leaving OFF")
            return
        }

        if !currentUser.enableFirebaseSync {
            currentUser.enableFirebaseSync = true
            saveCurrentUserLocally()
            print("☁️ UserManager: Migrated existing user to cloud sync ON")
        }

        // Back up current LOCAL data to cloud (idempotent save; local stays source of truth).
        syncToFirebase { success in
            print(success ? "☁️ UserManager: Local data backed up to cloud" : "⚠️ UserManager: Cloud backup failed (will retry next launch)")
        }
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
                enableFirebaseSync: true // DEFAULT ON - cloud backup
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

            // Local data is source of truth. Ensure sync is ON and push a backup to cloud.
            migrateEnableSyncIfNeeded()
            return
        }
        
        print("💾 UserManager: No local data found, creating new user with default wallet")
        print("🔍 WALLET DEBUG: This means existing wallets (like 'Rosebud') were not found!")
        print("🔍 WALLET DEBUG: User started fresh - all previous wallets lost")
        
        // Create default wallet for new users (name will be set based on user's name).
        // Stable id per identity so re-entry into this path never mints a duplicate default.
        let defaultWallet = AccountData(
            id: stableDefaultWalletID(),
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
            enableFirebaseSync: true // DEFAULT ON - cloud backup
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

            // The onboarding gate (isOnboardingComplete) reads the NUMERIC progress, so the
            // flags + state above are not enough on their own — bump the number to complete.
            // Without this the user is forced back through onboarding + paywall despite clearly
            // having finished before.
            if currentUser.onboardingCompleted < 16 {
                updateOnboardingProgress(16)
            }

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

    func updateUserStress(_ stress: String) {
        print("😫 UserManager: updateUserStress called with: '\(stress)'")

        currentUser.moneyStress = stress
        currentUser.updatedAt = Date()

        saveCurrentUserLocally()

        #if canImport(FirebaseFirestore)
        if currentUser.enableFirebaseSync {
            syncToFirebase { success in
                if success {
                    print("✅ UserManager: User stress synced to Firebase")
                } else {
                    print("❌ UserManager: Failed to sync user stress to Firebase")
                }
            }
        }
        #endif

        print("✅ UserManager: User stress updated to: '\(stress)'")
    }

    func updateUserOverspentRealization(_ overspent: String) {
        print("🙈 UserManager: updateUserOverspentRealization called with: '\(overspent)'")

        currentUser.overspentRealization = overspent
        currentUser.updatedAt = Date()

        saveCurrentUserLocally()

        #if canImport(FirebaseFirestore)
        if currentUser.enableFirebaseSync {
            syncToFirebase { success in
                if success {
                    print("✅ UserManager: User overspent realization synced to Firebase")
                } else {
                    print("❌ UserManager: Failed to sync user overspent realization to Firebase")
                }
            }
        }
        #endif

        print("✅ UserManager: User overspent realization updated to: '\(overspent)'")
    }

    func updateUserTrackingDifficulty(_ difficulty: String) {
        print("😣 UserManager: updateUserTrackingDifficulty called with: '\(difficulty)'")

        currentUser.trackingDifficulty = difficulty
        currentUser.updatedAt = Date()

        saveCurrentUserLocally()

        #if canImport(FirebaseFirestore)
        if currentUser.enableFirebaseSync {
            syncToFirebase { success in
                if success {
                    print("✅ UserManager: User tracking difficulty synced to Firebase")
                } else {
                    print("❌ UserManager: Failed to sync user tracking difficulty to Firebase")
                }
            }
        }
        #endif

        print("✅ UserManager: User tracking difficulty updated to: '\(difficulty)'")
    }

    func updateUserIdealOutcome(_ outcome: String) {
        print("🥳 UserManager: updateUserIdealOutcome called with: '\(outcome)'")

        currentUser.idealOutcome = outcome
        currentUser.updatedAt = Date()

        saveCurrentUserLocally()

        #if canImport(FirebaseFirestore)
        if currentUser.enableFirebaseSync {
            syncToFirebase { success in
                if success {
                    print("✅ UserManager: User ideal outcome synced to Firebase")
                } else {
                    print("❌ UserManager: Failed to sync user ideal outcome to Firebase")
                }
            }
        }
        #endif

        print("✅ UserManager: User ideal outcome updated to: '\(outcome)'")
    }

    func updateUserTrackingFrequency(_ frequency: String) {
        print("🕐 UserManager: updateUserTrackingFrequency called with: '\(frequency)'")

        currentUser.trackingFrequency = frequency
        currentUser.updatedAt = Date()

        saveCurrentUserLocally()

        #if canImport(FirebaseFirestore)
        if currentUser.enableFirebaseSync {
            syncToFirebase { success in
                if success {
                    print("✅ UserManager: User tracking frequency synced to Firebase")
                } else {
                    print("❌ UserManager: Failed to sync user tracking frequency to Firebase")
                }
            }
        }
        #endif

        print("✅ UserManager: User tracking frequency updated to: '\(frequency)'")
    }

    func updateUserTrackingMethod(_ method: String) {
        print("📝 UserManager: updateUserTrackingMethod called with: '\(method)'")

        currentUser.trackingMethod = method
        currentUser.updatedAt = Date()

        saveCurrentUserLocally()

        #if canImport(FirebaseFirestore)
        if currentUser.enableFirebaseSync {
            syncToFirebase { success in
                if success {
                    print("✅ UserManager: User tracking method synced to Firebase")
                } else {
                    print("❌ UserManager: Failed to sync user tracking method to Firebase")
                }
            }
        }
        #endif

        print("✅ UserManager: User tracking method updated to: '\(method)'")
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
    
    /// Update user's onboarding progression number.
    ///
    /// MONOTONIC BY DEFAULT (data-loss guard): auto-recompute paths must never LOWER a user's
    /// onboarding progress. A completed user (16) whose global boolean flags got wiped (e.g. a
    /// fresh install / cleared UserDefaults while the data box survived) was getting recomputed
    /// back to a low step and shoved through onboarding again. Only explicit resets (account
    /// deletion, last-wallet-deleted) may downgrade — those pass `allowDowngrade: true`.
    func updateOnboardingProgress(_ progress: Int, allowDowngrade: Bool = false) {
        if !allowDowngrade && progress < currentUser.onboardingCompleted {
            print("🛑 UserManager: refusing onboarding DOWNGRADE \(currentUser.onboardingCompleted) → \(progress) (monotonic guard)")
            return
        }
        print("🔢 UserManager: Updating onboarding progress: \(currentUser.onboardingCompleted) → \(progress)")
        currentUser.onboardingCompleted = progress
        currentUser.updatedAt = Date()

        // SINGLE SOURCE OF TRUTH: Only save locally - no Firebase sync for onboarding
        saveCurrentUserLocally()

        print("🔢 UserManager: Onboarding progress saved locally only (no Firebase sync)")
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
        
        // DELTA write: push just this one transaction to the cloud. Adding a transaction
        // doesn't touch wallets/budgets, so no full user-doc sync is needed.
        pushTransactionToCloud(transactionToSync)

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
                        let firebaseUserID = self.syncUID()
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
        let firebaseUserID = syncUID()
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
        let firebaseUserID = syncUID()
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
        let firebaseUserID = syncUID()
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
        let firebaseUserID = syncUID()
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
        let firebaseUserID = syncUID()
        
        currentUser.removeTransaction(withId: id)
        // Tombstone the id so a later merge (loadFromFirebase / connect) can NEVER resurrect it,
        // even if the cloud delete below fails or the user is offline.
        tombstoneTransaction(id)
        saveCurrentUserLocally()
        objectWillChange.send()

        // Propagate the deletion to the cloud so it's gone everywhere. Gated on sync being on.
        if currentUser.enableFirebaseSync, transaction != nil {
            // Shared tombstone FIRST: deleting the doc alone is ambiguous to other devices —
            // absence can't be told apart from "created offline, not uploaded yet".
            firestore.appendDeletedTransactionIDs([id.uuidString], userId: firebaseUserID)
            firestore.deleteTransaction(transactionId: id.uuidString, userId: firebaseUserID) { result in
                switch result {
                case .success():
                    print("✅ UserManager: Transaction \(id.uuidString.prefix(8)) deleted from Firebase")
                case .failure(let error):
                    // Local tombstone still protects against resurrection until the next
                    // successful sync retries the delete.
                    print("❌ UserManager: Failed to delete transaction from Firebase: \(error)")
                }
            }
        } else {
            print("📱 UserManager: Transaction deleted locally (sync off) — tombstoned")
        }

        print("🗑️ UserManager: Removed transaction with ID \(id)")
    }

    // MARK: - Deletion tombstones

    /// Ids of transactions the user has deleted. Merge operations subtract these so a stale
    /// cloud/box copy can never bring a deleted transaction back (zombie prevention).
    /// PER-USER key (was a single global key): one account's deletions must not suppress another
    /// account's same-id transactions on a shared device. Capped so it can't grow unbounded.
    private var tombstoneKey: String { "deletedTransactionIDs_\(syncUID())" }

    private static let tombstoneCap = 2000

    private var deletedTransactionIDs: Set<String> {
        get {
            // One-time migration of the legacy GLOBAL key into the current user's key.
            if let legacy = UserDefaults.standard.stringArray(forKey: "deletedTransactionIDs"), !legacy.isEmpty {
                var merged = Set(UserDefaults.standard.stringArray(forKey: tombstoneKey) ?? [])
                merged.formUnion(legacy)
                UserDefaults.standard.set(Array(merged), forKey: tombstoneKey)
                UserDefaults.standard.removeObject(forKey: "deletedTransactionIDs")
                return merged
            }
            return Set(UserDefaults.standard.stringArray(forKey: tombstoneKey) ?? [])
        }
        set {
            // Prune oldest-inserted (array order) beyond the cap so the list can't grow forever.
            var arr = Array(newValue)
            if arr.count > Self.tombstoneCap { arr = Array(arr.suffix(Self.tombstoneCap)) }
            UserDefaults.standard.set(arr, forKey: tombstoneKey)
        }
    }

    /// Apply the account's shared tombstone list: the cloud is the source of truth on deletions.
    /// Ids deleted on ANY device are unioned into this device's list and any local copy is dropped.
    /// Returns the merged set so callers can filter without re-reading UserDefaults.
    @discardableResult
    func applyCloudTombstones(_ cloudIDs: [String]) -> Set<String> {
        var ids = deletedTransactionIDs
        let before = ids.count
        ids.formUnion(cloudIDs)
        guard ids.count > before || currentUser.transactions.contains(where: { ids.contains($0.id.uuidString) }) else {
            return ids
        }
        deletedTransactionIDs = ids

        let doomed = currentUser.transactions.filter { ids.contains($0.id.uuidString) }
        guard !doomed.isEmpty else { return ids }

        currentUser.transactions.removeAll { ids.contains($0.id.uuidString) }
        saveCurrentUserLocally()
        objectWillChange.send()
        print("🗑️ UserManager: removed \(doomed.count) transaction(s) deleted on another device")
        return ids
    }

    private func tombstoneTransaction(_ id: UUID) {
        var ids = deletedTransactionIDs
        ids.insert(id.uuidString)
        deletedTransactionIDs = ids
    }
    
    func updateTransaction(_ transaction: Txn) {
        currentUser.updateTransaction(transaction)
        saveCurrentUserLocally()
        objectWillChange.send()

        // DELTA write: push only this changed transaction to the cloud.
        pushTransactionToCloud(transaction)

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

        // Budgets live in the user doc — debounced backup (coalesces rapid budget edits).
        backupSoon()
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

        // LOCAL-ONLY MODE: Firebase sync disabled for now
        // TODO: Re-enable when data sync feature is implemented
        print("📱 UserManager: Budget update saved locally only (Firebase sync disabled)")

        /*
        // Sync to Firebase
        syncToFirebase { success in
            if success {
                print("✅ UserManager: Budget update synced to Firebase")
            } else {
                print("⚠️ UserManager: Budget update sync to Firebase failed")
            }
        }
        */

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

        // Track budget deletion
        AnalyticsManager.shared.track(.budgetDeleted, properties: [
            "category": deletedBudget.categoryName,
            "amount": deletedBudget.amount,
            "period": deletedBudget.period.rawValue
        ])

        saveCurrentUserLocally()
        objectWillChange.send()

        // LOCAL-ONLY MODE: Firebase sync disabled for now
        // TODO: Re-enable when data sync feature is implemented
        print("📱 UserManager: Budget deletion saved locally only (Firebase sync disabled)")

        /*
        // Sync to Firebase
        syncToFirebase { success in
            if success {
                print("✅ UserManager: Budget deletion synced to Firebase")
            } else {
                print("⚠️ UserManager: Budget deletion sync to Firebase failed")
            }
        }
        */

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
        fullSyncToFirebase { success in
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
    
    // MARK: - Account Linking (guest/anonymous -> real login)

    /// Claim the current in-memory (guest/anonymous) data for a real account and make it
    /// cloud-backed. Called after any successful sign-in/sign-up. NON-DESTRUCTIVE: unions
    /// the guest data with whatever the account already has (local under the new key +
    /// cloud in Firestore), re-keys everything under `firebaseUID`, then pushes to cloud.
    /// This is what makes data "follow the login" the way the subscription already does.
    ///
    /// Merge rule (user-approved "merge both"):
    ///   - transactions: union by id; on id-collision keep the newer syncMetadata.lastModified.
    ///     Recurring templates + their children keep their ids, so parent/child links never dangle.
    ///   - accounts/wallets: existing mergeAccounts() union.
    ///   - onboarding: keep the furthest progress.
    func claimLocalDataIntoAccount(firebaseUID: String, completion: @escaping (Bool) -> Void = { _ in }) {
        print("🔗 UserManager: CLAIM - linking local data into account \(firebaseUID.prefix(8))…")

        // 1. Merge any data ALREADY stored locally under the new uid (returning user, same device).
        if let existingLocal = loadUserFromLocalStorage(firebaseUID: firebaseUID, userEmail: currentUser.email) {
            print("🔗 UserManager: CLAIM - found existing local data for this account, merging")
            currentUser.transactions = mergeTransactions(currentUser.transactions, existingLocal.transactions)
            currentUser.accounts = mergeAccounts(local: currentUser.accounts, firebase: existingLocal.accounts)
            if currentUser.onboardingCompleted < existingLocal.onboardingCompleted {
                currentUser.onboardingCompleted = existingLocal.onboardingCompleted
            }
        }

        currentUser.enableFirebaseSync = true

        // 2. Pull the account's CLOUD data and merge (returning user on a fresh install).
        #if canImport(FirebaseCore) && canImport(FirebaseFirestore)
        guard FirebaseApp.app() != nil else { finishClaim(completion: completion); return }
        firestore.fetchUserData(userId: firebaseUID) { [weak self] userResult in
            guard let self = self else { completion(false); return }
            if case .success(let cloudUser?) = userResult {
                DispatchQueue.main.async {
                    self.currentUser.accounts = self.mergeAccounts(local: self.currentUser.accounts, firebase: cloudUser.accounts)
                    if self.currentUser.name.isEmpty { self.currentUser.name = cloudUser.name }
                    // Restore onboarding progress from the cloud too — a returning user on a
                    // FRESH INSTALL has no local box, so without this they'd be forced through
                    // onboarding + the post-onboarding paywall on every login.
                    if self.currentUser.onboardingCompleted < cloudUser.onboardingCompleted {
                        self.currentUser.onboardingCompleted = cloudUser.onboardingCompleted
                    }
                    // Restore budgets from the cloud (union by id). Budgets live in the user doc and
                    // are written to cloud, but a fresh-install login had no path to read them back,
                    // so previously-set budgets vanished after signing in.
                    self.currentUser.budgets = self.mergeBudgets(self.currentUser.budgets, cloudUser.budgets)
                }
            }
            self.firestore.fetchTransactions(userId: firebaseUID) { txnResult in
                DispatchQueue.main.async {
                    if case .success(let cloudTxns) = txnResult, !cloudTxns.isEmpty {
                        print("🔗 UserManager: CLAIM - merging \(cloudTxns.count) cloud transactions")
                        self.currentUser.transactions = self.mergeTransactions(self.currentUser.transactions, cloudTxns)
                    }
                    self.finishClaim(completion: completion)
                }
            }
        }
        #else
        finishClaim(completion: completion)
        #endif
    }

    /// Persist the merged result under the new uid + push to Firestore.
    private func finishClaim(completion: @escaping (Bool) -> Void) {
        currentUser.updatedAt = Date()
        UserDefaults.standard.set(currentUser.id.uuidString, forKey: "currentUserId")
        UserDefaults.standard.set(currentUser.name, forKey: "currentUserName")
        UserDefaults.standard.set(currentUser.email, forKey: "currentUserEmail")
        // Returning user with real data (transactions / default wallet / prior completion flags)
        // should skip onboarding + the post-onboarding paywall. Do this BEFORE posting the
        // load-complete notification so the onboarding gate reads the corrected state.
        checkAndMarkOnboardingComplete()
        saveCurrentUserLocally() // keys by new firebaseUID + sets last_authenticated_firebase_uid
        ensureRoleAssigned()
        objectWillChange.send()
        NotificationCenter.default.post(name: NSNotification.Name("UserManagerFirebaseLoadComplete"), object: nil)
        print("🔗 UserManager: CLAIM - saved locally (\(currentUser.transactions.count) txns, \(currentUser.accounts.count) wallets), pushing to cloud")
        fullSyncToFirebase { success in
            print("🔗 UserManager: CLAIM - cloud push \(success ? "OK" : "failed (will retry on next sync)")")
            completion(success)
        }
    }

    /// Pull the account's data straight from Firebase and write it to this phone as a local save
    /// file (a new box in the "Upload local data" picker).
    ///
    /// Deliberately reads from Firestore rather than from `currentUser`: this is a snapshot of what
    /// the SOURCE OF TRUTH actually holds, not of what this device believes. It's a frozen archive
    /// — linked mirrors are the thing that stays live — so the box name carries the date it was
    /// taken and each download makes a new file rather than overwriting the last.
    ///
    /// Scope note: a box is a UserData, so this captures transactions, wallets and budgets.
    /// Categories and subscriptions live under their own storage keys and are not part of it.
    func downloadCloudDataToLocalFile(completion: @escaping (Result<Int, Error>) -> Void) {
        let uid = syncUID()

        firestore.fetchUserData(userId: uid) { [weak self] userResult in
            guard let self = self else { return }
            switch userResult {
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            case .success(let cloudUser):
                guard let cloudUser = cloudUser else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "NoCloudData", code: 404,
                            userInfo: [NSLocalizedDescriptionKey: "No cloud data found for this account"]
                        )))
                    }
                    return
                }

                // Transactions live in the subcollection, not in the user doc.
                self.firestore.fetchTransactions(userId: uid) { txnResult in
                    let cloudTxns = (try? txnResult.get()) ?? []
                    var snapshot = cloudUser
                    snapshot.transactions = cloudTxns
                    snapshot.updatedAt = Date()

                    let stamp = DateFormatter()
                    stamp.dateFormat = "yyyy-MM-dd-HHmm"
                    let label = stamp.string(from: Date())
                    snapshot.name = "Cloud backup \(label)"

                    do {
                        let encoded = try JSONEncoder().encode(snapshot)
                        UserDefaults.standard.set(encoded, forKey: "currentUser_firebase_cloud-\(label)")
                        print("⬇️ UserManager: saved cloud snapshot locally — \(cloudTxns.count) transactions")
                        DispatchQueue.main.async { completion(.success(cloudTxns.count)) }
                    } catch {
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
            }
        }
    }

    // MARK: - Linked local boxes (local mirrors of the account's data)

    /// Boxes the user attached to THIS account. Kept per-account so another login on the same
    /// phone doesn't inherit them.
    private var linkedBoxKey: String { "linkedLocalBoxes_\(syncUID())" }

    /// Cap the mirrors: each one is a full copy of the account's data in UserDefaults.
    private static let linkedBoxCap = 5

    func linkedLocalBoxUIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: linkedBoxKey) ?? []
    }

    private func markBoxLinked(_ uid: String) {
        var linked = linkedLocalBoxUIDs()
        guard !linked.contains(uid) else { return }
        linked.append(uid)
        if linked.count > Self.linkedBoxCap { linked = Array(linked.suffix(Self.linkedBoxCap)) }
        UserDefaults.standard.set(linked, forKey: linkedBoxKey)
        print("🔗 UserManager: box \(uid.prefix(8)) is now a linked local mirror")
    }

    /// Rewrite every linked box with the account's current state.
    ///
    /// These are MIRRORS, never sources: the app reads truth from Firebase (merged into the
    /// account box), and this copies that result outward. Before this, a connected box was a
    /// one-time snapshot that froze at the moment of upload and drifted forever after.
    private func mirrorToLinkedBoxes(_ encoded: Data) {
        let linked = linkedLocalBoxUIDs()
        guard !linked.isEmpty else { return }
        for uid in linked {
            UserDefaults.standard.set(encoded, forKey: "currentUser_firebase_\(uid)")
        }
    }

    /// The account's OWN local box, read back from disk rather than reported from memory — this
    /// answers "is my cloud data actually saved on this phone?" with what is really persisted.
    ///
    /// Every cloud merge ends in saveCurrentUserLocally(), so this box is the local mirror of the
    /// Firebase data. It is deliberately excluded from availableLocalDataBoxes() (you can't upload
    /// a box into itself), which is why it needed its own surface.
    func localCopySummary() -> LocalDataBox? {
        let uid = syncUID()
        guard let data = UserDefaults.standard.data(forKey: "currentUser_firebase_\(uid)"),
              let stored = try? JSONDecoder().decode(UserData.self, from: data) else { return nil }
        return LocalDataBox(
            uid: uid,
            name: stored.name,
            email: stored.email,
            transactionCount: stored.transactions.count,
            walletCount: stored.accounts.count,
            updatedAt: max(stored.updatedAt, stored.transactions.map(\.date).max() ?? .distantPast),
            isLinked: true
        )
    }

    /// All local data boxes on this device that hold data, other than the current account's
    /// own box. Powers the "Upload local data" picker so the user chooses which box to
    /// attach to their login. Sorted by transaction count (richest first).
    func availableLocalDataBoxes() -> [LocalDataBox] {
        let prefix = "currentUser_firebase_"
        let linked = Set(linkedLocalBoxUIDs())
        let currentUID = AuthenticationManager.shared.currentUser?.firebaseUID
        let d = UserDefaults.standard
        var boxes: [LocalDataBox] = []
        for key in d.dictionaryRepresentation().keys where
            key.hasPrefix(prefix) &&
            !key.hasSuffix("_preRestoreBackup") &&
            !key.hasSuffix("_legacy_backup") {
            let uid = String(key.dropFirst(prefix.count))
            if uid == currentUID { continue } // its own box — nothing to connect
            guard let data = d.data(forKey: key),
                  let u = try? JSONDecoder().decode(UserData.self, from: data) else { continue }
            if u.transactions.isEmpty && u.accounts.isEmpty { continue }
            boxes.append(LocalDataBox(
                uid: uid,
                name: u.name,
                email: u.email,
                transactionCount: u.transactions.count,
                walletCount: u.accounts.count,
                // Boxes written before updatedAt was stamped on save have a stale value, so fall
                // back to the newest transaction this box holds.
                updatedAt: max(u.updatedAt, u.transactions.map(\.date).max() ?? .distantPast),
                isLinked: linked.contains(uid)
            ))
        }
        return boxes.sorted {
            if $0.isLinked != $1.isLinked { return !$0.isLinked }   // actionable boxes first
            return $0.transactionCount > $1.transactionCount
        }
    }

    /// Attach a chosen local box to the currently signed-in account: its data is re-keyed to
    /// the login's Firebase UID and uploaded to the cloud. Non-destructive union with whatever
    /// the account already has; the source box is left in place as a safety copy.
    func connectLocalBox(sourceUID: String, completion: @escaping (Bool) -> Void = { _ in }) {
        guard AuthenticationManager.shared.currentUser?.firebaseUID != nil else {
            print("🔗 UserManager: CONNECT-BOX aborted — not signed in")
            completion(false); return
        }
        guard let data = UserDefaults.standard.data(forKey: "currentUser_firebase_\(sourceUID)"),
              let source = try? JSONDecoder().decode(UserData.self, from: data) else {
            print("🔗 UserManager: CONNECT-BOX aborted — source box \(sourceUID.prefix(8)) missing")
            completion(false); return
        }
        print("🔗 UserManager: CONNECT-BOX - re-keying box \(sourceUID.prefix(8)) (\(source.transactions.count) txns) to the logged-in account")
        currentUser.transactions = mergeTransactions(currentUser.transactions, source.transactions)
        currentUser.accounts = mergeAccounts(local: currentUser.accounts, firebase: source.accounts)
        if currentUser.onboardingCompleted < source.onboardingCompleted {
            currentUser.onboardingCompleted = source.onboardingCompleted
        }
        currentUser.enableFirebaseSync = true

        // From here the source box is a live mirror of this account, not a frozen snapshot.
        markBoxLinked(sourceUID)

        // Keep BOTH wallets (the merge already unions them). Select the wallet holding the most
        // transactions after the merge — that's the one with the real data, so new transactions
        // land there. Falls back to the imported box's default/first wallet if counts tie/empty.
        let walletTxnCounts = currentUser.transactions.reduce(into: [UUID: Int]()) { counts, txn in
            if let wid = txn.walletID { counts[wid, default: 0] += 1 }
        }
        let targetWalletId = walletTxnCounts.max(by: { $0.value < $1.value })?.key
            ?? source.accounts.first(where: { $0.isDefault })?.id
            ?? source.accounts.first?.id

        // Bring the source box's subscriptions over too (re-keyed to the account).
        Task { @MainActor in
            SubscriptionManager.shared.adoptSubscriptions(fromUID: sourceUID)
        }

        finishClaim { success in
            // Select the imported wallet AFTER the load-complete reload (which otherwise resets
            // selection to the account's default). Run last so this selection wins.
            if let targetWalletId {
                DispatchQueue.main.async {
                    AccountManager.shared.selectedSubAccountId = targetWalletId
                    AccountManager.shared.objectWillChange.send()
                    print("🎯 UserManager: CONNECT-BOX - selected imported wallet \(targetWalletId.uuidString.prefix(8))")
                }
            }
            completion(success)
        }
    }

    /// Union two transaction lists, unique by id. On id-collision keep the copy with the
    /// newer syncMetadata.lastModified. Keeps recurring templates + children intact. Any id
    /// the user has deleted (tombstoned) is dropped so a stale copy can't resurrect it.
    private func mergeTransactions(_ a: [Txn], _ b: [Txn]) -> [Txn] {
        var byId: [UUID: Txn] = [:]
        for t in a { byId[t.id] = t }
        for t in b {
            if let existing = byId[t.id] {
                byId[t.id] = (t.syncMetadata.lastModified > existing.syncMetadata.lastModified) ? t : existing
            } else {
                byId[t.id] = t
            }
        }
        let tombstones = deletedTransactionIDs
        let union = Array(byId.values).filter { !tombstones.contains($0.id.uuidString) }
        return collapseGeneratedDuplicates(union)
    }

    /// Collapse two copies of the SAME auto-generated occurrence created on different devices.
    /// A subscription/recurring child is minted locally with a fresh UUID, so the copy the other
    /// device generated for the same due date arrives from the cloud under a DIFFERENT id and
    /// survives the union-by-id above — that is the "subscription charged twice after a cloud
    /// load" bug. Neither generator can catch it: `transactionExistsForDate` only sees the local
    /// array, and `SubscriptionManager` drives off `nextDueDate` with no existence check at all.
    ///
    /// An occurrence is identified by (source subscription/template, due minute, amount). The due
    /// date comes from `nextDueDate`, which is identical on both devices, so this only ever matches
    /// genuine twins — two real charges in the same minute for the same amount would merge, which
    /// is the same assumption the generators already make.
    /// Does a generated transaction already exist for this subscription occurrence?
    ///
    /// Keyed the same way collapseGeneratedDuplicates keys duplicates — source id plus the due
    /// date to the minute — so the two agree on what "the same occurrence" means. Generation uses
    /// this to stay idempotent: collapse only runs inside mergeTransactions, so an occurrence
    /// generated locally AFTER a merge would otherwise sit next to the cloud's copy forever.
    func hasGeneratedOccurrence(sourceId: UUID, due: Date) -> Bool {
        let calendar = Calendar.current
        let dueMinute = calendar.date(bySetting: .second, value: 0, of: due) ?? due
        return currentUser.transactions.contains { txn in
            guard !txn.isRecurring,
                  let existingSource = txn.subscriptionId ?? txn.recurringTemplateId,
                  existingSource == sourceId else { return false }
            let txnMinute = calendar.date(bySetting: .second, value: 0, of: txn.date) ?? txn.date
            return txnMinute == dueMinute
        }
    }

    private func collapseGeneratedDuplicates(_ txns: [Txn]) -> [Txn] {
        struct OccurrenceKey: Hashable {
            let sourceId: UUID
            let minute: Date
            let amount: Double
        }

        let calendar = Calendar.current
        var survivors: [Txn] = []
        var indexByOccurrence: [OccurrenceKey: Int] = [:]

        for txn in txns {
            // Templates are not occurrences; only auto-generated children qualify.
            guard !txn.isRecurring,
                  let sourceId = txn.subscriptionId ?? txn.recurringTemplateId else {
                survivors.append(txn)
                continue
            }

            let key = OccurrenceKey(
                sourceId: sourceId,
                minute: calendar.date(bySetting: .second, value: 0, of: txn.date) ?? txn.date,
                amount: txn.amount
            )

            guard let existingIndex = indexByOccurrence[key] else {
                indexByOccurrence[key] = survivors.count
                survivors.append(txn)
                continue
            }

            // Deterministic winner so every device converges on the SAME surviving id:
            // the newer edit wins, ties break on the smaller uuid string.
            let existing = survivors[existingIndex]
            let winner: Txn
            if txn.syncMetadata.lastModified == existing.syncMetadata.lastModified {
                winner = txn.id.uuidString < existing.id.uuidString ? txn : existing
            } else {
                winner = txn.syncMetadata.lastModified > existing.syncMetadata.lastModified ? txn : existing
            }
            let loser = (winner.id == txn.id) ? existing : txn

            survivors[existingIndex] = winner
            // Tombstone the dropped copy so the other device's upload can't resurrect it.
            tombstoneTransaction(loser.id)
            print("🧹 UserManager: collapsed duplicate occurrence \(loser.id.uuidString.prefix(8)) — kept \(winner.id.uuidString.prefix(8)) for source \(sourceId.uuidString.prefix(8))")
        }

        return survivors
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
        let firebaseUserID = syncUID()
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
                        
                        // Merge accounts instead of replacing everything, honouring wallet
                        // tombstones from BOTH sides so a wallet deleted on the other device
                        // doesn't reappear here (and vice versa).
                        let walletMerge = self.mergeAccountTombstones(
                            localLive: self.currentUser.accounts,
                            localDeleted: self.currentUser.deletedAccounts,
                            cloudLive: userData.accounts,
                            cloudDeleted: userData.deletedAccounts
                        )
                        let mergedAccounts = walletMerge.live
                        
                        // Create updated user with merged accounts but preserve LOCAL onboarding state
                        let mergedUser = UserData(
                            id: userData.id,
                            name: userData.name,
                            email: userData.email,
                            transactions: self.currentUser.transactions, // Will be updated separately
                            accounts: mergedAccounts,
                            deletedAccounts: walletMerge.deleted,
                            // Budgets MUST be passed explicitly. The initializer defaults them to
                            // [], so omitting them here blanked currentUser.budgets on every cloud
                            // load and the following saveCurrentUserLocally persisted the blank.
                            budgets: self.mergeBudgets(self.currentUser.budgets, userData.budgets),
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
                        self.ensureRoleAssigned()
                        print("🔄 UserManager: Merged accounts - final count: \(mergedAccounts.count)")
                        print("🔄 UserManager: Final account names: \(mergedAccounts.map { $0.name })")
                    }
                } else {
                    print("⚠️ UserManager: No user data found in Firebase for ID: \(self.currentUser.id.uuidString)")
                }
                
                // Load transactions separately
                print("🔍 UserManager: Fetching transactions for user: \(self.currentUser.id.uuidString)")
                // Use Firebase UID for consistent Firebase operations
                let firebaseUserID = self.syncUID()
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

                            // MERGE, don't replace. An empty or stale cloud pull must NEVER wipe
                            // local transactions — that made balances "disappear" after sync.
                            // Union by id (newer syncMetadata.lastModified wins); keeps local data
                            // even when the cloud copy is behind, and persists the result.
                            let localBefore = self.currentUser.transactions
                            self.currentUser.transactions = self.mergeTransactions(localBefore, transactions)
                            self.hasLoadedFromFirebase = true
                            if self.currentUser.transactions.count != transactions.count {
                                // Local had data the cloud lacked — push the union back up.
                                self.saveCurrentUserLocally()
                            }

                            // Log after assignment
                            print("🔄 UserManager: AFTER merge - transaction count: \(self.currentUser.transactions.count) (local \(localBefore.count) + cloud \(transactions.count))")
                            print("☁️ UserManager: Merged \(transactions.count) cloud transactions")
                            print("💰 UserManager: Updated balance after Firebase sync: ₱\(String(format: "%.2f", self.currentUser.userBalance))")
                            
                            // Add a delay to see what happens to the data
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                print("⏰ UserManager: 2 seconds later - transaction count: \(self.currentUser.transactions.count)")
                                print("⏰ UserManager: 2 seconds later - balance: ₱\(String(format: "%.2f", self.currentUser.userBalance))")
                            }
                            
                            // Trigger UI update
                            self.objectWillChange.send()

                            // Validate budget-category links after data is loaded
                            CategoriesManager.shared.validateBudgetCategoryLinks()

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
    
    private var pendingBackupWork: DispatchWorkItem?

    /// Push a single transaction to the cloud (delta write, gated on sync). One doc, cheap —
    /// avoids re-uploading every transaction just because one changed.
    private func pushTransactionToCloud(_ transaction: Txn) {
        guard currentUser.enableFirebaseSync else { return }
        let firebaseUserID = syncUID()
        firestore.saveTransaction(transaction, userId: firebaseUserID) { result in
            if case .failure(let error) = result {
                print("❌ UserManager: cloud save failed for txn \(transaction.id.uuidString.prefix(8)): \(error)")
            }
        }
    }

    /// Debounced full backup (user doc + all transactions). Coalesces a burst of changes
    /// (wallet edits, rapid entries) into ONE upload ~2s after the last change, instead of
    /// firing a full sync per change. Explicit flows (connect, restore, sync toggle) still
    /// call syncToFirebase directly for immediate, awaited results.
    func backupSoon() {
        guard currentUser.enableFirebaseSync else { return }
        pendingBackupWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.syncToFirebase { _ in } }
        pendingBackupWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    /// Lightweight default sync: writes ONLY the user document (name/email/accounts/budgets/goals/
    /// onboarding/enableSync). Transactions are NOT looped here — they already sync individually
    /// via the delta `pushTransactionToCloud` on add/update. Most callers (field, account, budget
    /// changes) want exactly this. Use `fullSyncToFirebase` when you've mutated the transaction
    /// array in bulk (login claim, recurring-txn generation, migrations, force-sync).
    func syncToFirebase(completion: @escaping (Bool) -> Void) {
        guard currentUser.enableFirebaseSync else {
            print("🚫 UserManager: Firebase sync disabled for user - skipping sync")
            completion(true)
            return
        }
        DispatchQueue.main.async { self.isSyncingToCloud = true }
        firestore.saveUserData(currentUser, userId: syncUID()) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success():
                    self.markCloudSync(succeeded: true)
                    completion(true)
                case .failure(let error):
                    self.firebaseError = "Failed to sync user data: \(error.localizedDescription)"
                    self.markCloudSync(succeeded: false)
                    completion(false)
                }
            }
        }
    }

    /// Full sync: user document PLUS every transaction pushed to the subcollection. Heavier —
    /// only for callers that changed the transaction array in bulk (login claim, recurring-txn
    /// generation, migrations, explicit force-sync).
    func fullSyncToFirebase(completion: @escaping (Bool) -> Void) {
        // Check if Firebase sync is enabled for this user
        guard currentUser.enableFirebaseSync else {
            print("🚫 UserManager: Firebase sync disabled for user - skipping sync")
            completion(true) // Return success since user chose not to sync
            return
        }

        DispatchQueue.main.async { self.isSyncingToCloud = true }

        // Save user data under the Firebase UID (same doc fetchUserData reads + parent of the
        // transactions subcollection), so wallets/budgets survive reinstall.
        let userDocID = syncUID()
        firestore.saveUserData(currentUser, userId: userDocID) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success():
                // Save all transactions
                let dispatchGroup = DispatchGroup()
                var hasErrors = false

                for transaction in self.currentUser.transactions {
                    dispatchGroup.enter()
                    // Use Firebase UID for consistent Firebase operations
                    let firebaseUserID = self.syncUID()
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
                        self.markCloudSync(succeeded: false)
                        completion(false)
                    } else {
                        print("☁️ UserManager: All data synced to Firebase successfully")
                        self.markCloudSync(succeeded: true)
                        completion(true)
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.firebaseError = "Failed to sync user data: \(error.localizedDescription)"
                    self.markCloudSync(succeeded: false)
                    completion(false)
                }
            }
        }
    }

    /// Record the outcome of a cloud sync so the UI can show the truth (backed up / failed).
    private func markCloudSync(succeeded: Bool) {
        isSyncingToCloud = false
        lastCloudSyncFailed = !succeeded
        if succeeded {
            let now = Date()
            lastCloudSyncAt = now
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastCloudSyncAt")
        }
    }

    func clearFirebaseError() {
        firebaseError = nil
    }
    
    // MARK: - Sync Manager Integration
    // Repointed off TransactionSyncManager (disabled in Phase 1) onto UserManager's own sync
    // state, so the UI's "force sync" / status drive the single remaining engine.

    /// Get current sync status
    func getSyncStatus() -> SyncStatus {
        if isSyncingToCloud { return .syncing }
        if lastCloudSyncFailed { return .error(message: "Sync failed") }
        if let at = lastCloudSyncAt { return .synced(lastSyncDate: at) }
        return .notSynced
    }

    /// Force immediate sync (full push through the single engine).
    func forceSync() {
        guard currentUser.enableFirebaseSync else {
            print("⏸️ UserManager.forceSync: sync disabled by user")
            return
        }
        fullSyncToFirebase { success in
            print("🔄 UserManager.forceSync: \(success ? "OK" : "failed")")
        }
    }

    /// Check if transactions are currently syncing
    var isSyncing: Bool {
        return isSyncingToCloud
    }

    /// Get pending changes count (no longer tracked per-change; 0 = up to date/idle)
    var pendingChangesCount: Int {
        return 0
    }

    /// Get last sync date
    var lastSyncDate: Date? {
        return lastCloudSyncAt
    }

    /// Clear sync errors
    func clearSyncError() {
        lastCloudSyncFailed = false
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
        // Tombstone BEFORE removing: the record (with a fresh updatedAt) is what tells the other
        // devices this wallet is gone. Dropping it silently just means the next merge re-adds it
        // from the cloud copy, and the other device pushes it straight back up.
        if var doomed = currentUser.accounts.first(where: { $0.id == accountId }) {
            doomed.isDefault = false          // a tombstone must never win the default election
            doomed.updatedAt = Date()
            currentUser.deletedAccounts.removeAll { $0.id == accountId }
            currentUser.deletedAccounts.append(doomed)
        }
        currentUser.removeAccount(withId: accountId)
        
        // Check if this was the last wallet - if so, reset onboarding to 1
        if currentUser.accounts.isEmpty {
            print("🚨 UserManager: Last wallet deleted - resetting onboarding to step 1 (name collection)")
            print("   User will skip email verification but redo name/currency/goals setup")
            updateOnboardingProgress(1, allowDowngrade: true) // explicit reset — allowed to lower
            
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
    
    /// Union budgets by id; on collision the newer `updatedAt` wins. Preserves local-only budgets
    /// and pulls in any the cloud has that this device lacks (fresh-install restore).
    private func mergeBudgets(_ local: [Budget], _ cloud: [Budget]) -> [Budget] {
        var byId: [UUID: Budget] = [:]
        for b in local { byId[b.id] = b }
        for b in cloud {
            if let existing = byId[b.id] {
                if b.updatedAt > existing.updatedAt { byId[b.id] = b }
            } else {
                byId[b.id] = b
            }
        }
        return Array(byId.values)
    }

    // MARK: - Account Merging
    
    /// Intelligently merge local and Firebase accounts to preserve local changes
    /// Resolve wallet tombstones across the two sides, then merge the survivors.
    ///
    /// A wallet is dead if EITHER side holds a tombstone for it that is newer than that side's
    /// live copy. Last-write-wins, so re-creating a wallet with the same id after deleting it
    /// still works — the newer live record beats the older tombstone.
    private func mergeAccountTombstones(
        localLive: [AccountData], localDeleted: [AccountData],
        cloudLive: [AccountData], cloudDeleted: [AccountData]
    ) -> (live: [AccountData], deleted: [AccountData]) {
        var tombstones: [UUID: AccountData] = [:]
        for record in localDeleted + cloudDeleted {
            if let existing = tombstones[record.id], existing.updatedAt >= record.updatedAt { continue }
            tombstones[record.id] = record
        }

        // A live record newer than the tombstone means the wallet was re-created — drop the stone.
        for record in localLive + cloudLive {
            if let stone = tombstones[record.id], record.updatedAt > stone.updatedAt {
                tombstones.removeValue(forKey: record.id)
            }
        }

        let live = mergeAccounts(
            local: localLive.filter { tombstones[$0.id] == nil },
            firebase: cloudLive.filter { tombstones[$0.id] == nil }
        )
        return (live, Array(tombstones.values))
    }

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
        
        // 3. Ensure EXACTLY ONE default account. After a union two wallets can both carry
        // isDefault (the account's own + a connected box's), which makes wallet selection
        // ambiguous. Keep the first default (the account's own — local accounts are processed
        // first) and clear any others. New transactions then follow the SELECTED wallet
        // unambiguously, whichever the user picks.
        if mergedAccounts.isEmpty {
            print("⚠️ No accounts after merge, creating default wallet...")
            let defaultWallet = AccountData(
                id: stableDefaultWalletID(), // Stable per identity so it never piles up
                name: "", // Empty name - will be set during onboarding
                type: .personal,
                currency: .usd, // Temporary placeholder - will be updated during currency selection onboarding
                isDefault: true
            )
            mergedAccounts.append(defaultWallet)
        } else if let cloudDefaultId = firebase.first(where: { $0.isDefault })?.id,
                  let cloudDefaultIndex = mergedAccounts.firstIndex(where: { $0.id == cloudDefaultId }) {
            // SIGNED-IN RULE: the account's own default wallet wins. Keeping the first default in
            // list order meant a wallet created on this phone (local is processed first) became
            // the default the moment you signed in — and since every view filters by the selected
            // wallet, the account's real transactions looked like they hadn't synced at all.
            mergedAccounts[cloudDefaultIndex].isDefault = true
            for i in mergedAccounts.indices where i != cloudDefaultIndex && mergedAccounts[i].isDefault {
                mergedAccounts[i].isDefault = false
                print("🔧 Cleared local default on '\(mergedAccounts[i].name)' — cloud default wins")
            }
        } else if let firstDefaultIndex = mergedAccounts.firstIndex(where: { $0.isDefault }) {
            // Exactly one default: keep the first, clear the rest.
            for i in mergedAccounts.indices where i != firstDefaultIndex && mergedAccounts[i].isDefault {
                mergedAccounts[i].isDefault = false
                print("🔧 Cleared duplicate default on '\(mergedAccounts[i].name)'")
            }
        } else {
            // No default at all - make the first one default
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
    /// Remove auto-created default-wallet placeholders that pile up on login. When a user signs
    /// in, the anonymous/guest session's empty "Personal Wallet" placeholder gets merged into the
    /// real account (its id differs from the account's own default, so the merge keeps both), and
    /// each fresh anonymous session mints a new one. This prunes them:
    ///   • Only ever touches EMPTY (zero-transaction) wallets named like the auto default
    ///     ("", "Personal", "Personal Wallet"). Wallets with data or a custom name are never removed.
    ///   • If the account has ANY real wallet (holds transactions, or is custom-named), remove ALL
    ///     the empty placeholders — a real user doesn't need a blank "Personal Wallet" clutter row.
    ///   • If EVERY wallet is an empty placeholder (brand-new user), keep exactly one.
    /// Always leaves ≥1 wallet with exactly one default. Non-destructive to real data.
    @discardableResult
    func dedupeAutoDefaultWallets() -> Bool {
        let autoNames: Set<String> = ["", "personal", "personal wallet"]
        let txnCounts = currentUser.transactions.reduce(into: [UUID: Int]()) { counts, txn in
            if let wid = txn.walletID { counts[wid, default: 0] += 1 }
        }
        func isEmptyPlaceholder(_ a: AccountData) -> Bool {
            autoNames.contains(a.name.lowercased()) && (txnCounts[a.id] ?? 0) == 0
        }
        let placeholders = currentUser.accounts.filter(isEmptyPlaceholder)
        let realWallets = currentUser.accounts.filter { !isEmptyPlaceholder($0) }

        // Which placeholders to drop:
        //  - real wallets exist → drop every placeholder.
        //  - only placeholders exist → keep one (prefer default, then stable-id, then first).
        let removeIDs: Set<UUID>
        if !realWallets.isEmpty {
            guard !placeholders.isEmpty else { return false }
            removeIDs = Set(placeholders.map { $0.id })
        } else {
            guard placeholders.count > 1 else { return false }
            let stableID = stableDefaultWalletID()
            let survivor = placeholders.first(where: { $0.isDefault })
                ?? placeholders.first(where: { $0.id == stableID })
                ?? placeholders[0]
            removeIDs = Set(placeholders.map { $0.id }).subtracting([survivor.id])
        }

        print("🧹 UserManager: Pruning \(removeIDs.count) empty default-wallet placeholder(s) (real wallets: \(realWallets.count))")
        currentUser.accounts.removeAll { removeIDs.contains($0.id) }
        // Ensure EXACTLY ONE default remains without stealing default from a real user wallet:
        // keep the first default (a real wallet wins since it may sort ahead), clear the rest,
        // and if nothing is default, promote the first account.
        if let firstDefault = currentUser.accounts.firstIndex(where: { $0.isDefault }) {
            for i in currentUser.accounts.indices where i != firstDefault && currentUser.accounts[i].isDefault {
                currentUser.accounts[i].isDefault = false
            }
        } else if !currentUser.accounts.isEmpty {
            currentUser.accounts[0].isDefault = true
        }
        currentUser.updatedAt = Date()
        saveCurrentUserLocally()
        return true
    }

    /// THE one canonical identity for every cloud/local key — box key (`currentUser_firebase_<uid>`),
    /// Firestore doc id (`users/<uid>`), and any per-user storage. Prefers the live Firebase UID;
    /// else the persisted pointer from the last authenticated session (stable across the pre-auth
    /// window); else the app UUID as a last resort. Using the pointer instead of a fresh
    /// `currentUser.id.uuidString` stops the key churning to a random UUID before Firebase Auth
    /// finishes loading — the root cause of the "wallets/data lost on launch, fresh start" bug.
    func syncUID() -> String {
        if let f = AuthenticationManager.shared.currentUser?.firebaseUID, !f.isEmpty { return f }
        if let p = UserDefaults.standard.string(forKey: "last_authenticated_firebase_uid"), !p.isEmpty { return p }
        return currentUser.id.uuidString
    }

    /// Stable, persisted default-wallet id for the current identity. Every place that
    /// auto-creates a "Personal" default wallet reuses THIS id, so repeated setup passes
    /// (app launch, each UserManagerFirebaseLoadComplete, the merge fallback) collapse into
    /// ONE wallet on merge instead of minting a fresh-UUID "Personal" that piles up on every
    /// login. Keyed per identity so each real account/guest still gets its own single default.
    func stableDefaultWalletID() -> UUID {
        let uid = syncUID()
        let key = "defaultWalletID_\(uid)"
        if let stored = UserDefaults.standard.string(forKey: key),
           let id = UUID(uuidString: stored) {
            return id
        }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }

    /// Rolling local safety snapshot (3 slots) of the last good non-empty state, per identity.
    /// Cheap insurance: if any future bug corrupts/blanks the live data, `restoreFromSafetySnapshot`
    /// can bring back the richest recent copy. Skips writing an identical slot.
    private func writeSafetySnapshot(_ data: Data, uid: String) {
        let d = UserDefaults.standard
        let slotKey = "safetySnapSlot_\(uid)"
        let slot = d.integer(forKey: slotKey) % 3
        let snapKey = "safetySnap_\(uid)_\(slot)"
        if let existing = d.data(forKey: snapKey), existing == data { return }
        d.set(data, forKey: snapKey)
        d.set(slot + 1, forKey: slotKey)
    }

    /// Manual rescue: if the current data has fewer transactions than a saved snapshot, restore the
    /// richest snapshot for this identity. Returns true if it recovered anything.
    @discardableResult
    func restoreFromSafetySnapshot() -> Bool {
        let uid = syncUID()
        var best: UserData?
        var bestCount = currentUser.transactions.count
        for slot in 0..<3 {
            if let data = UserDefaults.standard.data(forKey: "safetySnap_\(uid)_\(slot)"),
               let u = try? JSONDecoder().decode(UserData.self, from: data),
               u.transactions.count > bestCount {
                best = u; bestCount = u.transactions.count
            }
        }
        guard let recovered = best else { return false }
        print("♻️ UserManager: restoring \(recovered.transactions.count) txns from safety snapshot")
        currentUser = recovered
        saveCurrentUserLocally()
        objectWillChange.send()
        return true
    }

    func saveCurrentUserLocally() {
        // SECURITY: Verify wallet ownership before saving
        verifyWalletOwnership()

        // Stamp the box as changed NOW. updatedAt was only ever bumped by profile-level edits
        // (name, goals, role), so a box could take hundreds of new transactions and still report
        // "last update 2 weeks ago" in the Upload local data picker.
        currentUser.updatedAt = Date()
        
        print("💾 UserManager: SAVING USER DATA TO LOCAL STORAGE")
        print("   👤 User: \(currentUser.name) (\(currentUser.email))")
        print("   🆔 User ID: \(currentUser.id.uuidString)")
        print("   🏦 Wallets to save: \(currentUser.accounts.count)")
        print("   🎯 Budgets to save: \(currentUser.budgets.count)")
        
        for (index, account) in currentUser.accounts.enumerated() {
            print("   \(index + 1). '\(account.name)' (\(account.id.uuidString.prefix(8))...) - Default: \(account.isDefault)")
        }
        
        print("   📊 Transactions to save: \(currentUser.transactions.count)")
        print("   ☁️ Firebase sync enabled: \(currentUser.enableFirebaseSync)")
        
        do {
            let encoded = try JSONEncoder().encode(currentUser)

            // Use Firebase UID for consistent storage key
            let firebaseUID = syncUID()
            let key = "currentUser_firebase_\(firebaseUID)"

            // ── DATA-LOSS GUARDRAIL ─────────────────────────────────────────────────────────
            // Refuse to overwrite a box that HAS data with a currentUser that looks like a fresh
            // reset (blank/default name AND no transactions). Identity churn / reset bugs used to
            // silently blank real data this way. A user genuinely deleting everything keeps their
            // name + wallets, so this only blocks the accidental-wipe pattern, not real edits.
            let looksLikeReset = currentUser.transactions.isEmpty &&
                (currentUser.name.trimmingCharacters(in: .whitespaces).isEmpty ||
                 currentUser.name == "Cashmonki User")
            if looksLikeReset,
               let existingData = UserDefaults.standard.data(forKey: key),
               let existing = try? JSONDecoder().decode(UserData.self, from: existingData),
               !existing.transactions.isEmpty {
                print("🛑 UserManager: SAFETY — refusing to overwrite box \(firebaseUID.prefix(8)) (\(existing.transactions.count) txns) with empty/reset data")
                return
            }
            // Keep a rolling local safety snapshot of the LAST good non-empty state, so any future
            // corruption is recoverable. Written BEFORE the overwrite.
            if !currentUser.transactions.isEmpty {
                writeSafetySnapshot(encoded, uid: firebaseUID)
            }
            // ────────────────────────────────────────────────────────────────────────────────

            UserDefaults.standard.set(encoded, forKey: key)

            // Keep every linked box current with the same bytes. Firebase remains the source of
            // truth; these are local copies of what came back from it.
            mirrorToLinkedBoxes(encoded)

            // CRITICAL: Store Firebase UID separately for recovery after app restart
            // This allows us to find the correct storage key before Firebase Auth loads
            UserDefaults.standard.set(firebaseUID, forKey: "last_authenticated_firebase_uid")

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
                    print("   🎯 Verified budget count: \(verifyUser.budgets.count)")
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
        print("💾 UserManager: Attempting to load user data from local storage...")

        // STEP 1: Get the Firebase UID (try live auth first, then stored fallback)
        let firebaseUID: String? = AuthenticationManager.shared.currentUser?.firebaseUID
            ?? UserDefaults.standard.string(forKey: "last_authenticated_firebase_uid")

        // STEP 2: Try the primary key format (matches how we save)
        if let uid = firebaseUID {
            let primaryKey = "currentUser_firebase_\(uid)"
            print("💾 UserManager: Trying primary key: \(primaryKey)")

            if let data = UserDefaults.standard.data(forKey: primaryKey),
               let user = try? JSONDecoder().decode(UserData.self, from: data) {
                print("✅ UserManager: Loaded user data from local storage (key: \(primaryKey))")
                print("   👤 User: \(user.name)")
                print("   📊 Transactions: \(user.transactions.count)")
                print("   🏦 Wallets: \(user.accounts.count)")
                return user
            }
        } else {
            print("⚠️ UserManager: No Firebase UID available for primary key lookup")
        }

        // STEP 3: Fallback to legacy keys for backward compatibility
        let legacyKeys = [
            "currentUser_\(currentUser.id.uuidString)",
            "currentUser",
            "userData"
        ]

        for key in legacyKeys {
            if let data = UserDefaults.standard.data(forKey: key),
               let user = try? JSONDecoder().decode(UserData.self, from: data) {
                print("💾 UserManager: Loaded user data from legacy key: \(key)")
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
    /// Push local transactions the cloud has never seen. Called right after a successful sign-in
    /// restore: the merge brings the account's data DOWN, this sends anything device-only UP, so
    /// a phone that was offline (or whose writes were rejected) stops being the only copy.
    ///
    /// Deliberately only uploads ids that existed locally BEFORE the merge — rows that arrived
    /// from the cloud in this same pass obviously don't need sending back.
    func uploadTransactionsMissingFromCloud(localIDsBeforeRestore: Set<UUID>) {
        guard currentUser.enableFirebaseSync else { return }
        let uid = syncUID()

        // Pull the shared tombstones BEFORE deciding what's "missing" — otherwise a row deleted
        // on another device looks device-only here and gets re-uploaded (resurrection).
        firestore.fetchDeletedTransactionIDs(userId: uid) { [weak self] tombResult in
            guard let self = self else { return }
            let tombstoned = self.applyCloudTombstones((try? tombResult.get()) ?? [])

        self.firestore.fetchTransactions(userId: uid) { [weak self] result in
            guard let self = self, case .success(let cloudTxns) = result else { return }
            let cloudIDs = Set(cloudTxns.map(\.id))
            let missing = self.currentUser.transactions.filter {
                localIDsBeforeRestore.contains($0.id)
                    && !cloudIDs.contains($0.id)
                    && !tombstoned.contains($0.id.uuidString)
            }
            guard !missing.isEmpty else {
                print("☁️ UserManager: cloud already has every local transaction")
                return
            }
            print("⬆️ UserManager: uploading \(missing.count) device-only transaction(s) the cloud was missing")
            for txn in missing {
                self.firestore.saveTransaction(txn, userId: uid) { r in
                    if case .failure(let e) = r {
                        print("❌ UserManager: upload failed for \(txn.id.uuidString.prefix(8)): \(e.localizedDescription)")
                    }
                }
            }
        }
        }
    }

    // MARK: - Live Cloud Apply (CloudSync)

    /// Apply a user document pushed by the live listener. Merges — never replaces — so a snapshot
    /// that arrives mid-edit can't drop local work. Onboarding stays local by design.
    /// Deep equality via canonical JSON. `.sortedKeys` keeps the encoding stable so two
    /// value-identical arrays always produce identical bytes.
    private static func contentEqual<T: Encodable>(_ a: [T], _ b: [T]) -> Bool {
        guard a.count == b.count else { return false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let da = try? encoder.encode(a), let db = try? encoder.encode(b) else { return false }
        return da == db
    }

    func applyCloudUserDoc(_ cloud: UserData) {
        guard currentUser.enableFirebaseSync else { return }

        let walletMerge = mergeAccountTombstones(
            localLive: currentUser.accounts,
            localDeleted: currentUser.deletedAccounts,
            cloudLive: cloud.accounts,
            cloudDeleted: cloud.deletedAccounts
        )
        let mergedAccounts = walletMerge.live
        let mergedBudgets = mergeBudgets(currentUser.budgets, cloud.budgets)

        // Compare CONTENT, not counts. Count-only detection missed every same-count edit —
        // wallet rename, budget amount change, category reassignment — so the merged value sat in
        // memory but was never written to disk, and the local mirror silently fell behind.
        let accountsChanged = !Self.contentEqual(mergedAccounts, currentUser.accounts)
            || !Self.contentEqual(walletMerge.deleted, currentUser.deletedAccounts)
        let budgetsChanged = !Self.contentEqual(mergedBudgets, currentUser.budgets)
        let nameChanged = currentUser.name.isEmpty && !cloud.name.isEmpty

        currentUser.accounts = mergedAccounts
        currentUser.deletedAccounts = walletMerge.deleted
        currentUser.budgets = mergedBudgets
        if nameChanged { currentUser.name = cloud.name }

        guard accountsChanged || budgetsChanged || nameChanged else { return }
        saveCurrentUserLocally()
        objectWillChange.send()
        print("📡 CloudSync: applied user doc — \(mergedAccounts.count) wallets, \(mergedBudgets.count) budgets")
    }

    /// Adopt any wallet a synced transaction references but this account doesn't have yet.
    ///
    /// A transaction created on another device carries that device's walletID. If the wallet
    /// itself hasn't reached the user document yet, every view filters those transactions out —
    /// they exist locally, count toward nothing, and look lost. Adopting a placeholder wallet
    /// keeps the transactions visible under their OWN wallet instead of reassigning them to a
    /// different one, which would silently move money between wallets.
    ///
    /// The placeholder is stamped `.distantPast`, so when the real wallet does arrive,
    /// mergeAccounts takes the real name/type over this stub (same id, newer updatedAt wins).
    private func adoptMissingWallets() {
        let knownWalletIDs = Set(currentUser.accounts.map(\.id))
        let referenced = Set(currentUser.transactions.compactMap(\.walletID))
        let missing = referenced.subtracting(knownWalletIDs)
        guard !missing.isEmpty else { return }

        for walletID in missing {
            let count = currentUser.transactions.filter { $0.walletID == walletID }.count
            currentUser.accounts.append(
                AccountData(
                    id: walletID,
                    name: "Synced Wallet",
                    isDefault: false,
                    createdAt: .distantPast,
                    updatedAt: .distantPast
                )
            )
            print("🔗 UserManager: adopted missing wallet \(walletID.uuidString.prefix(8)) — \(count) synced transaction(s) were invisible without it")
        }
        AccountManager.shared.objectWillChange.send()
    }

    /// Apply the transaction set pushed by the live listener. Union-by-id with tombstones and
    /// duplicate collapsing, so this is idempotent — our own writes echoing back change nothing.
    func applyCloudTransactions(_ cloud: [Txn]) {
        guard currentUser.enableFirebaseSync else { return }

        let before = currentUser.transactions
        let merged = mergeTransactions(before, cloud)

        // Cheap change test: same count AND same id set means nothing to do.
        if merged.count == before.count {
            let beforeIDs = Set(before.map(\.id))
            if merged.allSatisfy({ beforeIDs.contains($0.id) }) { return }
        }

        currentUser.transactions = merged
        // Synced rows may reference a wallet this account has never seen; without it they are
        // filtered out of every list and total.
        adoptMissingWallets()
        saveCurrentUserLocally()
        objectWillChange.send()
        print("📡 CloudSync: applied transactions — \(before.count) local + \(cloud.count) cloud → \(merged.count)")
    }

    /// Storage key for the explicit "I turned cloud backup off" preference.
    private func syncOptOutKey() -> String { "enableFirebaseSync_\(syncUID())" }

    /// True when the user has explicitly opted out of cloud backup for this identity. Also reads
    /// the legacy `currentUser.id`-keyed value so an opt-out saved before the key moved is still
    /// honoured (and re-saves it under the stable key so it survives the next sign-in).
    private func syncOptOutIsExplicit() -> Bool {
        let d = UserDefaults.standard
        let key = syncOptOutKey()
        if d.object(forKey: key) != nil { return d.bool(forKey: key) == false }

        let legacyKey = "enableFirebaseSync_\(currentUser.id.uuidString)"
        if d.object(forKey: legacyKey) != nil {
            let legacyValue = d.bool(forKey: legacyKey)
            d.set(legacyValue, forKey: key)   // adopt under the stable key
            return legacyValue == false
        }
        return false
    }

    func setFirebaseSyncEnabled(_ enabled: Bool) {
        currentUser.enableFirebaseSync = enabled
        currentUser.updatedAt = Date()
        
        // IMPORTANT: Save this preference immediately to persist across app restarts.
        // Keyed on syncUID(), NOT currentUser.id — AuthenticationManager mints a fresh UUID()
        // for currentUser.id on every sign-in, so a preference stored under it was written to a
        // key nothing would ever read again. The old value said "off", migrateEnableSyncIfNeeded
        // couldn't see it, and the next login turned sync back ON and uploaded.
        UserDefaults.standard.set(enabled, forKey: syncOptOutKey())
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("🔄 UserManager: Firebase sync \(enabled ? "enabled" : "disabled") for user")
        print("💾 UserManager: Sync preference saved to UserDefaults")

        // Live listeners follow the toggle: attach when backup is on, drop them when it's off.
        CloudSync.shared.refresh()
        
        // If enabling sync and we have data, sync immediately
        if enabled && !currentUser.transactions.isEmpty {
            print("📤 UserManager: Syncing existing data to Firebase...")
            fullSyncToFirebase { success in
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
        
        fullSyncToFirebase { success in
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
            let firebaseUserID = syncUID()
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
