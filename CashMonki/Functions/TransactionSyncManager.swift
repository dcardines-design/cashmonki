//
//  TransactionSyncManager.swift
//  CashMonki
//
//  Created by Claude on 10/23/25.
//

import Foundation
import SwiftUI
import SwiftData

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Manages bidirectional sync between local SwiftData storage and Firebase Cloud Firestore
/// Ensures transactions are consistent across devices and provides offline capabilities
class TransactionSyncManager: ObservableObject {
    static let shared = TransactionSyncManager()
    
    // MARK: - Published Properties
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var pendingChangesCount = 0
    
    // MARK: - Private Properties
    private let firestoreService = FirestoreService.shared
    private weak var userManager: UserManager?
    private var syncTimer: Timer?
    #if canImport(FirebaseFirestore)
    private var listeners: [ListenerRegistration] = []
    #endif
    
    // Sync configuration
    private let autoSyncInterval: TimeInterval = 30.0 // 30 seconds
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    
    // Change tracking
    private var pendingLocalChanges: Set<UUID> = []
    private var isRealTimeListening = false
    
    private init() {
        print("🔄 TransactionSyncManager: Initializing sync manager")
        setupAutoSync()
        setupNetworkMonitoring()
    }
    
    deinit {
        stopRealTimeSync()
        syncTimer?.invalidate()
    }
    
    // MARK: - Setup Methods
    
    /// Set the user manager reference to avoid circular dependencies
    func setUserManager(_ userManager: UserManager) {
        self.userManager = userManager
        print("🔗 TransactionSyncManager: UserManager reference set")
    }
    
    // MARK: - Public Sync Methods
    
    /// Start comprehensive bidirectional sync
    func startSync() {
        print("🚀 TransactionSyncManager: Starting bidirectional sync")
        
        guard isFirebaseAvailable() else {
            print("⚠️ TransactionSyncManager: Firebase not available, sync disabled")
            return
        }
        
        // Start real-time listeners
        startRealTimeSync()
        
        // Only perform initial sync if we have data to sync
        // Otherwise, let UserManager handle the initial data load
        if let userManager = userManager, !userManager.currentUser.transactions.isEmpty {
            print("📊 TransactionSyncManager: Found existing data, performing initial sync")
            performFullSync()
        } else {
            print("📭 TransactionSyncManager: No existing data, skipping initial sync - UserManager will handle first load")
        }
    }
    
    /// Stop all sync operations
    func stopSync() {
        print("🛑 TransactionSyncManager: Stopping sync operations")
        stopRealTimeSync()
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    /// Force immediate bidirectional sync
    func forcSync() {
        print("⚡ TransactionSyncManager: Force sync requested")
        performFullSync()
    }
    
    /// Sync specific transaction (called when transaction is added/updated locally)
    func syncTransaction(_ transaction: Txn, operation: SyncOperation) {
        print("📝 TransactionSyncManager: Syncing transaction \(transaction.id.uuidString.prefix(8)) - \(operation)")
        
        guard isFirebaseAvailable() else {
            addToPendingChanges(transaction.id)
            return
        }
        
        switch operation {
        case .create, .update:
            syncTransactionToFirebase(transaction)
        case .delete:
            deleteTransactionFromFirebase(transaction)
        }
    }
    
    // MARK: - Real-Time Sync
    
    private func startRealTimeSync() {
        print("👂 TransactionSyncManager: Starting real-time Firebase listeners")
        
        guard isFirebaseAvailable(), !isRealTimeListening else { return }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        guard let userManager = userManager else {
            print("⚠️ TransactionSyncManager: UserManager not set, cannot start real-time sync")
            return
        }
        let userId = userManager.currentUser.id.uuidString
        
        // Listen to user's transaction collection
        let transactionsRef = db.collection("users")
            .document(userId)
            .collection("transactions")
            .order(by: "date", descending: true)
        
        let listener = transactionsRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ TransactionSyncManager: Real-time listener error: \(error)")
                DispatchQueue.main.async {
                    self.syncError = "Real-time sync error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let snapshot = snapshot else { return }
            
            print("👂 TransactionSyncManager: Received real-time update - \(snapshot.documents.count) documents")
            
            // Process document changes
            self.processFirebaseChanges(snapshot.documentChanges)
        }
        
        listeners.append(listener)
        isRealTimeListening = true
        
        print("✅ TransactionSyncManager: Real-time listeners started")
        #endif
    }
    
    private func stopRealTimeSync() {
        print("🛑 TransactionSyncManager: Stopping real-time listeners")
        
        #if canImport(FirebaseFirestore)
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        #endif
        isRealTimeListening = false
    }
    
    #if canImport(FirebaseFirestore)
    private func processFirebaseChanges(_ changes: [DocumentChange]) {
        print("🔄 TransactionSyncManager: Processing \(changes.count) Firebase changes")
        
        var hasUpdates = false
        
        for change in changes {
            let documentId = change.document.documentID
            let data = change.document.data()
            
            switch change.type {
            case .added:
                print("➕ TransactionSyncManager: Firebase added: \(documentId.prefix(8))")
                if let transaction = parseFirebaseTransaction(data, id: documentId) {
                    addTransactionToLocal(transaction)
                    hasUpdates = true
                }
                
            case .modified:
                print("✏️ TransactionSyncManager: Firebase modified: \(documentId.prefix(8))")
                if let transaction = parseFirebaseTransaction(data, id: documentId) {
                    updateTransactionInLocal(transaction)
                    hasUpdates = true
                }
                
            case .removed:
                print("🗑️ TransactionSyncManager: Firebase removed: \(documentId.prefix(8))")
                if let transactionId = UUID(uuidString: documentId) {
                    removeTransactionFromLocal(transactionId)
                    hasUpdates = true
                }
            }
        }
        
        if hasUpdates {
            DispatchQueue.main.async {
                self.userManager?.objectWillChange.send()
                self.lastSyncDate = Date()
                print("✅ TransactionSyncManager: Local data updated from Firebase changes")
            }
        }
    }
    #endif
    
    // MARK: - Full Sync Operations
    
    private func performFullSync() {
        guard !isSyncing else {
            print("⏳ TransactionSyncManager: Sync already in progress, skipping")
            return
        }
        
        DispatchQueue.main.async {
            self.isSyncing = true
            self.syncError = nil
        }
        
        print("🔄 TransactionSyncManager: Starting full bidirectional sync")
        
        // Step 1: Push pending local changes to Firebase
        pushLocalChangesToFirebase { [weak self] success in
            guard let self = self else { return }
            
            if success {
                // Step 2: Pull latest changes from Firebase
                self.pullFirebaseChangesToLocal { pullSuccess in
                    DispatchQueue.main.async {
                        self.isSyncing = false
                        if pullSuccess {
                            self.lastSyncDate = Date()
                            self.pendingChangesCount = 0
                            print("✅ TransactionSyncManager: Full sync completed successfully")
                        } else {
                            self.syncError = "Failed to pull changes from Firebase"
                            print("❌ TransactionSyncManager: Full sync failed during pull phase")
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.syncError = "Failed to push changes to Firebase"
                    print("❌ TransactionSyncManager: Full sync failed during push phase")
                }
            }
        }
    }
    
    private func pushLocalChangesToFirebase(completion: @escaping (Bool) -> Void) {
        print("⬆️ TransactionSyncManager: Pushing local changes to Firebase")
        
        guard let userManager = userManager else {
            print("⚠️ TransactionSyncManager: UserManager not set, cannot push changes")
            completion(false)
            return
        }
        
        let localTransactions = userManager.currentUser.transactions
        let userId = userManager.currentUser.id.uuidString
        
        guard !localTransactions.isEmpty else {
            print("📭 TransactionSyncManager: No local transactions to push")
            completion(true)
            return
        }
        
        print("📤 TransactionSyncManager: Pushing \(localTransactions.count) transactions to Firebase")
        
        let dispatchGroup = DispatchGroup()
        var errors: [Error] = []
        
        for transaction in localTransactions {
            dispatchGroup.enter()
            
            firestoreService.saveTransaction(transaction, userId: userId) { result in
                switch result {
                case .success():
                    print("✅ TransactionSyncManager: Pushed \(transaction.id.uuidString.prefix(8))")
                case .failure(let error):
                    print("❌ TransactionSyncManager: Failed to push \(transaction.id.uuidString.prefix(8)): \(error)")
                    errors.append(error)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .global(qos: .utility)) {
            let success = errors.isEmpty
            print("📤 TransactionSyncManager: Push completed - \(success ? "Success" : "Failed with \(errors.count) errors")")
            completion(success)
        }
    }
    
    private func pullFirebaseChangesToLocal(completion: @escaping (Bool) -> Void) {
        print("⬇️ TransactionSyncManager: Pulling changes from Firebase")
        
        guard let userManager = userManager else {
            print("⚠️ TransactionSyncManager: UserManager not set, cannot pull changes")
            completion(false)
            return
        }
        
        let userId = userManager.currentUser.id.uuidString
        
        firestoreService.fetchTransactions(userId: userId) { [weak self] result in
            guard let self = self else {
                completion(false)
                return
            }
            
            switch result {
            case .success(let firebaseTransactions):
                print("📥 TransactionSyncManager: Received \(firebaseTransactions.count) transactions from Firebase")
                
                // Merge with local transactions
                self.mergeFirebaseTransactionsWithLocal(firebaseTransactions)
                completion(true)
                
            case .failure(let error):
                print("❌ TransactionSyncManager: Failed to pull from Firebase: \(error)")
                completion(false)
            }
        }
    }
    
    private func mergeFirebaseTransactionsWithLocal(_ firebaseTransactions: [Txn]) {
        print("🔀 TransactionSyncManager: Merging Firebase transactions with local data")
        
        guard let userManager = userManager else {
            print("⚠️ TransactionSyncManager: UserManager not set, cannot merge transactions")
            return
        }
        
        let localTransactions = userManager.currentUser.transactions
        var mergedTransactions: [Txn] = []
        
        // Create dictionaries for efficient lookup
        let localTxnDict = Dictionary(uniqueKeysWithValues: localTransactions.map { ($0.id, $0) })
        let firebaseTxnDict = Dictionary(uniqueKeysWithValues: firebaseTransactions.map { ($0.id, $0) })
        
        // Get all unique transaction IDs
        let allTransactionIds = Set(localTxnDict.keys).union(Set(firebaseTxnDict.keys))
        
        for txnId in allTransactionIds {
            let localTxn = localTxnDict[txnId]
            let firebaseTxn = firebaseTxnDict[txnId]
            
            switch (localTxn, firebaseTxn) {
            case (let local?, let firebase?):
                // Both exist - use most recently updated
                let txnToUse = local.createdAt > firebase.createdAt ? local : firebase
                mergedTransactions.append(txnToUse)
                
                if local.createdAt != firebase.createdAt {
                    print("🔀 TransactionSyncManager: Conflict resolved for \(txnId.uuidString.prefix(8)) - using \(txnToUse.createdAt > local.createdAt ? "Firebase" : "local") version")
                }
                
            case (let local?, nil):
                // Only local - keep it (will be synced to Firebase)
                mergedTransactions.append(local)
                print("📱 TransactionSyncManager: Local-only transaction: \(txnId.uuidString.prefix(8))")
                
            case (nil, let firebase?):
                // Only Firebase - add to local
                mergedTransactions.append(firebase)
                print("☁️ TransactionSyncManager: Firebase-only transaction: \(txnId.uuidString.prefix(8))")
                
            case (nil, nil):
                // This shouldn't happen
                print("⚠️ TransactionSyncManager: Both local and Firebase are nil for \(txnId)")
            }
        }
        
        // Update local data
        DispatchQueue.main.async {
            guard let userManager = self.userManager else { return }
            let beforeCount = userManager.currentUser.transactions.count
            userManager.currentUser.transactions = mergedTransactions
            let afterCount = mergedTransactions.count
            
            print("🔀 TransactionSyncManager: Merge completed - \(beforeCount) → \(afterCount) transactions")
            userManager.objectWillChange.send()
        }
    }
    
    // MARK: - Individual Transaction Sync
    
    private func syncTransactionToFirebase(_ transaction: Txn) {
        let userId = transaction.userId.uuidString
        
        firestoreService.saveTransaction(transaction, userId: userId) { [weak self] result in
            switch result {
            case .success():
                print("✅ TransactionSyncManager: Synced transaction \(transaction.id.uuidString.prefix(8)) to Firebase")
                self?.removeFromPendingChanges(transaction.id)
                
            case .failure(let error):
                print("❌ TransactionSyncManager: Failed to sync transaction: \(error)")
                self?.addToPendingChanges(transaction.id)
                
                DispatchQueue.main.async {
                    self?.syncError = "Failed to sync transaction: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteTransactionFromFirebase(_ transaction: Txn) {
        let userId = transaction.userId.uuidString
        
        firestoreService.deleteTransaction(transactionId: transaction.id.uuidString, userId: userId) { [weak self] result in
            switch result {
            case .success():
                print("✅ TransactionSyncManager: Deleted transaction \(transaction.id.uuidString.prefix(8)) from Firebase")
                self?.removeFromPendingChanges(transaction.id)
                
            case .failure(let error):
                print("❌ TransactionSyncManager: Failed to delete transaction: \(error)")
                self?.addToPendingChanges(transaction.id)
                
                DispatchQueue.main.async {
                    self?.syncError = "Failed to delete transaction: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Local Data Management
    
    private func addTransactionToLocal(_ transaction: Txn) {
        guard let userManager = userManager else { return }
        // Check if transaction already exists locally
        let existingIndex = userManager.currentUser.transactions.firstIndex { $0.id == transaction.id }
        
        if existingIndex == nil {
            // Ensure transaction has a valid accountId (assign to default account if missing)
            var transactionToAdd = transaction
            if transaction.accountId == nil {
                if let defaultAccountId = userManager.currentUser.defaultSubAccount?.id {
                    transactionToAdd = Txn(
                        id: transaction.id,
                        userId: transaction.userId,
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
                        accountId: defaultAccountId, // Set default account ID
                        originalAmount: transaction.originalAmount,
                        originalCurrency: transaction.originalCurrency,
                        primaryCurrency: transaction.primaryCurrency,
                        secondaryCurrency: transaction.secondaryCurrency,
                        exchangeRate: transaction.exchangeRate,
                        secondaryAmount: transaction.secondaryAmount,
                        secondaryExchangeRate: transaction.secondaryExchangeRate
                    )
                    print("🔧 TransactionSyncManager: Assigned transaction \(transaction.id.uuidString.prefix(8)) to default account")
                }
            }
            
            // Use UserManager.addTransaction to properly handle notifications and account assignment
            userManager.addTransaction(transactionToAdd)
            print("➕ TransactionSyncManager: Added Firebase transaction to local: \(transaction.id.uuidString.prefix(8))")
        } else {
            print("⚠️ TransactionSyncManager: Transaction \(transaction.id.uuidString.prefix(8)) already exists locally")
        }
    }
    
    private func updateTransactionInLocal(_ transaction: Txn) {
        guard let userManager = userManager else { return }
        if userManager.currentUser.transactions.contains(where: { $0.id == transaction.id }) {
            // Use UserManager.updateTransaction to properly handle notifications
            userManager.updateTransaction(transaction)
            print("✏️ TransactionSyncManager: Updated local transaction: \(transaction.id.uuidString.prefix(8))")
        } else {
            // Transaction doesn't exist locally, add it
            addTransactionToLocal(transaction)
        }
    }
    
    private func removeTransactionFromLocal(_ transactionId: UUID) {
        guard let userManager = userManager else { return }
        // Use UserManager.removeTransaction to properly handle notifications
        userManager.removeTransaction(withId: transactionId)
        print("🗑️ TransactionSyncManager: Removed local transaction: \(transactionId.uuidString.prefix(8))")
    }
    
    // MARK: - Helper Methods
    
    private func isFirebaseAvailable() -> Bool {
        #if canImport(FirebaseCore)
        return FirebaseApp.app() != nil
        #else
        return false
        #endif
    }
    
    private func parseFirebaseTransaction(_ data: [String: Any], id: String) -> Txn? {
        do {
            return try firestoreService.convertFirestoreDataToTransaction(data, transactionId: id, userId: nil)
        } catch {
            print("❌ TransactionSyncManager: Failed to parse Firebase transaction \(id.prefix(8)): \(error)")
            return nil
        }
    }
    
    // MARK: - Pending Changes Management
    
    private func addToPendingChanges(_ transactionId: UUID) {
        pendingLocalChanges.insert(transactionId)
        DispatchQueue.main.async {
            self.pendingChangesCount = self.pendingLocalChanges.count
        }
        print("📋 TransactionSyncManager: Added to pending changes: \(transactionId.uuidString.prefix(8)) (total: \(pendingLocalChanges.count))")
    }
    
    private func removeFromPendingChanges(_ transactionId: UUID) {
        pendingLocalChanges.remove(transactionId)
        DispatchQueue.main.async {
            self.pendingChangesCount = self.pendingLocalChanges.count
        }
        print("✅ TransactionSyncManager: Removed from pending changes: \(transactionId.uuidString.prefix(8)) (remaining: \(pendingLocalChanges.count))")
    }
    
    // MARK: - Auto Sync Setup
    
    private func setupAutoSync() {
        print("⏰ TransactionSyncManager: Setting up auto-sync timer (\(autoSyncInterval)s interval)")
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.pendingChangesCount > 0 {
                print("⏰ TransactionSyncManager: Auto-sync triggered - \(self.pendingChangesCount) pending changes")
                self.performFullSync()
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        // Monitor network connectivity and resume sync when connection is restored
        // This is a simplified implementation - in production you might use Network framework
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 TransactionSyncManager: App became active - checking for pending sync")
            self?.performFullSync()
        }
    }
    
    // MARK: - Sync Status Methods
    
    func getSyncStatus() -> SyncStatus {
        if isSyncing {
            return .syncing
        } else if pendingChangesCount > 0 {
            return .pendingChanges(count: pendingChangesCount)
        } else if let lastSync = lastSyncDate {
            return .synced(lastSyncDate: lastSync)
        } else {
            return .notSynced
        }
    }
    
    func clearSyncError() {
        syncError = nil
    }
}

// MARK: - Supporting Types

enum SyncOperation {
    case create
    case update
    case delete
}

enum SyncStatus {
    case syncing
    case synced(lastSyncDate: Date)
    case pendingChanges(count: Int)
    case notSynced
    case error(message: String)
    
    var description: String {
        switch self {
        case .syncing:
            return "Syncing..."
        case .synced(let date):
            return "Synced \(formatRelativeTime(date))"
        case .pendingChanges(let count):
            return "\(count) pending changes"
        case .notSynced:
            return "Not synced"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

