import Foundation
import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Firebase Firestore service for transaction and user data persistence.
/// Compiles and provides fallback behavior when Firebase is unavailable.
final class FirestoreService {
    static let shared = FirestoreService()

    #if canImport(FirebaseFirestore)
    private var db: Firestore? {
        // Only create Firestore instance if Firebase is configured
        guard FirebaseApp.app() != nil else {
            print("⚠️ FirestoreService: Firebase not configured, cannot create Firestore instance")
            return nil
        }
        return Firestore.firestore()
    }
    #endif

    private init() {}

    // MARK: - Helper Methods
    
    /// Get user name for a given user ID
    private func getUserName(for userId: String) -> String {
        // First check if this matches the current UserManager user
        let currentUserManager = UserManager.shared
        if currentUserManager.currentUser.id.uuidString == userId {
            return currentUserManager.currentUser.name
        }
        
        // Then check if this matches the authenticated user
        if let authUser = AuthenticationManager.shared.currentUser,
           authUser.id.uuidString == userId {
            return authUser.name
        }
        
        // Finally check hardcoded IDs for legacy support
        switch userId {
        case "12345678-1234-1234-1234-123456789ABC":
            return "Dante Cardines III"
        case "C4AD521B-D633-42C5-8A9E-7557A3208B35":
            return "Old User (Temporary)"
        default:
            return "Unknown User"
        }
    }

    // MARK: - User Data Management
    
    func saveUserData(_ userData: UserData, completion: @escaping (Result<Void, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        do {
            let userRef = db.collection("users").document(userData.id.uuidString)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(userData)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            userRef.setData(dict) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
        #else
        completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not available"])))
        #endif
    }
    
    func fetchUserData(userId: String, completion: @escaping (Result<UserData?, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data() else {
                completion(.success(nil))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                let userData = try decoder.decode(UserData.self, from: jsonData)
                completion(.success(userData))
            } catch {
                completion(.failure(error))
            }
        }
        #else
        completion(.success(nil))
        #endif
    }

    // MARK: - Transaction Management
    
    func saveTransaction(_ transaction: Txn, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Get user name for debug logging (outside conditional compilation)
        let userName = getUserName(for: userId)
        
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ Firebase: Database not available - Firebase may not be configured properly")
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        print("✅ Firebase: Database connection available for transaction save")
        
        do {
            // Convert transaction to Firestore-compatible format
            let transactionData = try transactionToFirestoreData(transaction)
            
            let transactionRef = db.collection("users")
                .document(userId)
                .collection("transactions")
                .document(transaction.id.uuidString)
            
            print("💾 Firebase: Saving transaction \(transaction.id.uuidString.prefix(8)) for user \(userName) (\(userId.prefix(8)))")
            print("💾 Firebase: Transaction data: \(transaction.category) ₱\(transaction.amount)")
            
            // DEBUG: Check if userId is in the data being sent
            if let userIdInData = transactionData["userId"] as? String {
                print("✅ Firebase: userId field present in data: \(userIdInData.prefix(8))")
            } else {
                print("❌ Firebase: userId field MISSING from data being sent!")
            }
            
            // DEBUG: Show all fields being sent
            print("📋 Firebase: All fields being sent: \(transactionData.keys.sorted())")
            
            transactionRef.setData(transactionData) { error in
                if let error = error {
                    print("❌ Firebase: Failed to save transaction \(transaction.id.uuidString.prefix(8)) for \(userName): \(error)")
                    completion(.failure(error))
                } else {
                    print("✅ Firebase: Successfully saved transaction \(transaction.id.uuidString.prefix(8)) for \(userName) to nested collection")
                    
                    // ALSO save to top-level transactions collection for global queries
                    // This ensures userId field is available in the top-level collection
                    let globalTransactionRef = db.collection("transactions").document(transaction.id.uuidString)
                    
                    print("🌐 Firebase: ALSO saving to global transactions collection with userId field...")
                    globalTransactionRef.setData(transactionData) { globalError in
                        if let globalError = globalError {
                            print("⚠️ Firebase: Failed to save to global transactions collection: \(globalError)")
                            // Don't fail the whole operation - nested save already succeeded
                        } else {
                            print("✅ Firebase: Successfully saved transaction to GLOBAL transactions collection with userId")
                        }
                        
                        // Save receipt image separately if it exists
                        if let receiptImage = transaction.receiptImage {
                            self.saveReceiptImage(receiptImage, transactionId: transaction.id.uuidString, userId: userId) { _ in
                                // Continue regardless of image save result
                                completion(.success(()))
                            }
                        } else {
                            completion(.success(()))
                        }
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
        #else
        completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1)))
        #endif
    }
    
    func fetchTransactions(userId: String, completion: @escaping (Result<[Txn], Error>) -> Void) {
        // Get user name for debug logging (outside conditional compilation)
        let userName = getUserName(for: userId)
        
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        let transactionsRef = db.collection("users")
            .document(userId)
            .collection("transactions")
            .order(by: "date", descending: true)
        
        print("🔍 Firebase: Fetching transactions for \(userName) from users/\(userId.prefix(8))/transactions")
        
        transactionsRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firebase: Failed to fetch transactions: \(error)")
                completion(.failure(error))
                return
            }
            
            let documentCount = snapshot?.documents.count ?? 0
            print("📥 Firebase: Retrieved \(documentCount) documents from Firestore")
            
            // Debug: Show all document IDs and basic info
            if let documents = snapshot?.documents {
                if documents.isEmpty {
                    print("🔍 Firebase: EMPTY COLLECTION - No documents found in users/\(userId.prefix(8))/transactions")
                } else {
                    print("🔍 Firebase: Document IDs in collection:")
                    for (index, doc) in documents.enumerated() {
                        let docData = doc.data()
                        let category = docData["category"] as? String ?? "unknown"
                        let amount = docData["amount"] as? Double ?? 0.0
                        print("   \(index + 1). \(doc.documentID.prefix(8)): \(category) ₱\(amount)")
                    }
                }
            }
            
            let transactions = snapshot?.documents.compactMap { doc -> Txn? in
                print("🔄 Firebase: Processing document \(doc.documentID.prefix(8))")
                do {
                    let transaction = try self.firestoreDataToTransaction(doc.data(), transactionId: doc.documentID, userId: userId)
                    print("✅ Firebase: Successfully decoded transaction \(doc.documentID.prefix(8)): \(transaction.category)")
                    return transaction
                } catch {
                    print("❌ Firebase: Failed to decode transaction \(doc.documentID): \(error)")
                    return nil
                }
            } ?? []
            
            print("📊 Firebase: Final transaction count after decoding: \(transactions.count)")
            completion(.success(transactions))
        }
        #else
        completion(.success([]))
        #endif
    }
    
    /// Debug function to check what users and transactions exist in Firebase
    func debugFirebaseContents() {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ Firebase Debug: Database not available")
            return
        }
        
        print("🔍 Firebase Debug: Checking all users in database...")
        
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firebase Debug: Failed to fetch users: \(error)")
                return
            }
            
            let userCount = snapshot?.documents.count ?? 0
            print("👥 Firebase Debug: Found \(userCount) users in database")
            
            if let documents = snapshot?.documents {
                for (index, doc) in documents.enumerated() {
                    let userId = doc.documentID
                    print("   \(index + 1). User: \(userId.prefix(12))...")
                    
                    // Check transactions for this user
                    db.collection("users").document(userId).collection("transactions").getDocuments { txnSnapshot, txnError in
                        if let txnError = txnError {
                            print("      ❌ Error fetching transactions: \(txnError)")
                        } else {
                            let txnCount = txnSnapshot?.documents.count ?? 0
                            print("      📊 Transactions: \(txnCount)")
                            
                            if txnCount > 0, let txnDocs = txnSnapshot?.documents {
                                for (txnIndex, txnDoc) in txnDocs.prefix(3).enumerated() {
                                    let data = txnDoc.data()
                                    let category = data["category"] as? String ?? "unknown"
                                    let amount = data["amount"] as? Double ?? 0.0
                                    print("         \(txnIndex + 1). \(category): ₱\(amount)")
                                }
                                if txnDocs.count > 3 {
                                    print("         ... and \(txnDocs.count - 3) more")
                                }
                            }
                        }
                    }
                }
            }
        }
        #else
        print("❌ Firebase Debug: Firebase not available")
        #endif
    }
    
    /// Get the most recent transaction for a user
    func getMostRecentTransaction(userId: String, completion: @escaping (Result<Txn?, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1)))
            return
        }
        
        print("🔍 Firebase: Fetching most recent transaction for user \(userId.prefix(8))")
        
        db.collection("users")
            .document(userId)
            .collection("transactions")
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Firebase: Failed to fetch recent transaction: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    print("📝 Firebase: No transactions found for user")
                    completion(.success(nil))
                    return
                }
                
                do {
                    let transaction = try self.firestoreDataToTransaction(document.data(), transactionId: document.documentID, userId: userId)
                    print("✅ Firebase: Most recent transaction: \(transaction.category) ₱\(transaction.amount) on \(transaction.createdAt)")
                    completion(.success(transaction))
                } catch {
                    print("❌ Firebase: Failed to decode recent transaction: \(error)")
                    completion(.failure(error))
                }
            }
        #else
        completion(.success(nil))
        #endif
    }
    
    /// Search for recent transactions by merchant name or amount
    func searchRecentTransactions(userId: String, searchTerm: String, completion: @escaping (Result<[Txn], Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1)))
            return
        }
        
        print("🔍 Firebase: Searching for transactions with: '\(searchTerm)'")
        
        db.collection("users")
            .document(userId)
            .collection("transactions")
            .order(by: "date", descending: true)
            .limit(to: 20) // Get last 20 transactions
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Firebase: Search failed: \(error)")
                    completion(.failure(error))
                    return
                }
                
                let allTransactions = snapshot?.documents.compactMap { doc -> Txn? in
                    do {
                        return try self.firestoreDataToTransaction(doc.data(), transactionId: doc.documentID, userId: userId)
                    } catch {
                        return nil
                    }
                } ?? []
                
                // Filter by search term (merchant name or amount)
                let filteredTransactions = allTransactions.filter { txn in
                    // Check merchant name
                    if let merchantName = txn.merchantName?.lowercased(), 
                       merchantName.contains(searchTerm.lowercased()) {
                        return true
                    }
                    // Check amount (convert to string for matching)
                    if String(abs(txn.amount)).contains(searchTerm) {
                        return true
                    }
                    return false
                }
                
                print("🔍 Firebase: Found \(filteredTransactions.count) transactions matching '\(searchTerm)'")
                for (index, txn) in filteredTransactions.enumerated() {
                    print("   \(index + 1). \(txn.merchantName ?? "Unknown") - ₱\(txn.amount) - \(txn.createdAt)")
                }
                
                completion(.success(filteredTransactions))
            }
        #else
        completion(.success([]))
        #endif
    }
    
    func deleteTransaction(transactionId: String, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        let transactionRef = db.collection("users")
            .document(userId)
            .collection("transactions")
            .document(transactionId)
        
        transactionRef.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Also delete receipt image if it exists
                self.deleteReceiptImage(transactionId: transactionId, userId: userId) { _ in
                    // Continue regardless of image deletion result
                    completion(.success(()))
                }
            }
        }
        #else
        completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1)))
        #endif
    }
    
    /// Load transactions for a specific user (alias for fetchTransactions for compatibility)
    func loadTransactions(userId: String, completion: @escaping (Result<[Txn], Error>) -> Void) {
        print("🔄 FirestoreService: loadTransactions called for user \(userId.prefix(8))")
        fetchTransactions(userId: userId, completion: completion)
    }
    
    /// Clear all transactions for a user (debug method)
    func clearAllTransactions(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        let userName = getUserName(for: userId)
        print("🗑️ Firebase: Clearing all transactions for \(userName)")
        
        let transactionsRef = db.collection("users")
            .document(userId)
            .collection("transactions")
        
        transactionsRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firebase: Failed to get transactions for clearing: \(error)")
                completion(.failure(error))
                return
            }
            
            let documents = snapshot?.documents ?? []
            print("🗑️ Firebase: Found \(documents.count) transactions to delete")
            
            let batch = db.batch()
            for document in documents {
                batch.deleteDocument(document.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("❌ Firebase: Failed to clear transactions: \(error)")
                    completion(.failure(error))
                } else {
                    print("✅ Firebase: Successfully cleared \(documents.count) transactions for \(userName)")
                    completion(.success(()))
                }
            }
        }
        #else
        completion(.success(()))
        #endif
    }
    
    /// Delete ALL user data for account deletion (comprehensive)
    func deleteAllUserData(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        let userName = getUserName(for: userId)
        print("🗑️ Firebase: COMPREHENSIVE USER DATA DELETION for \(userName) (ID: \(userId.prefix(8)))")
        
        let dispatchGroup = DispatchGroup()
        var deletionErrors: [String] = []
        var deletedCounts: [String: Int] = [:]
        
        // 1. Delete nested transactions collection: users/{userId}/transactions/
        dispatchGroup.enter()
        print("🗑️ Firebase: Step 1 - Deleting nested transactions...")
        db.collection("users").document(userId).collection("transactions").getDocuments { snapshot, error in
            if let error = error {
                deletionErrors.append("Nested transactions error: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            let transactions = snapshot?.documents ?? []
            deletedCounts["nested_transactions"] = transactions.count
            print("🗑️ Firebase: Found \(transactions.count) nested transactions to delete")
            
            let batch = db.batch()
            for doc in transactions {
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { batchError in
                if let batchError = batchError {
                    deletionErrors.append("Nested transactions batch error: \(batchError.localizedDescription)")
                } else {
                    print("✅ Firebase: Deleted \(transactions.count) nested transactions")
                }
                dispatchGroup.leave()
            }
        }
        
        // 2. Delete receipt images collection: users/{userId}/receiptImages/
        dispatchGroup.enter()
        print("🗑️ Firebase: Step 2 - Deleting receipt images...")
        db.collection("users").document(userId).collection("receiptImages").getDocuments { snapshot, error in
            if let error = error {
                deletionErrors.append("Receipt images error: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            let images = snapshot?.documents ?? []
            deletedCounts["receipt_images"] = images.count
            print("🗑️ Firebase: Found \(images.count) receipt images to delete")
            
            let batch = db.batch()
            for doc in images {
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { batchError in
                if let batchError = batchError {
                    deletionErrors.append("Receipt images batch error: \(batchError.localizedDescription)")
                } else {
                    print("✅ Firebase: Deleted \(images.count) receipt images")
                }
                dispatchGroup.leave()
            }
        }
        
        // 3. Delete global transactions that belong to this user: transactions/ where userId == userId
        dispatchGroup.enter()
        print("🗑️ Firebase: Step 3 - Deleting global transactions...")
        db.collection("transactions").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                deletionErrors.append("Global transactions error: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            let globalTransactions = snapshot?.documents ?? []
            deletedCounts["global_transactions"] = globalTransactions.count
            print("🗑️ Firebase: Found \(globalTransactions.count) global transactions to delete")
            
            let batch = db.batch()
            for doc in globalTransactions {
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { batchError in
                if let batchError = batchError {
                    deletionErrors.append("Global transactions batch error: \(batchError.localizedDescription)")
                } else {
                    print("✅ Firebase: Deleted \(globalTransactions.count) global transactions")
                }
                dispatchGroup.leave()
            }
        }
        
        // 4. Delete legacy account documents: accounts/ where userId == userId
        dispatchGroup.enter()
        print("🗑️ Firebase: Step 4 - Deleting legacy account documents...")
        db.collection("accounts").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                deletionErrors.append("Legacy accounts error: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            let accounts = snapshot?.documents ?? []
            deletedCounts["legacy_accounts"] = accounts.count
            print("🗑️ Firebase: Found \(accounts.count) legacy account documents to delete")
            
            let batch = db.batch()
            for doc in accounts {
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { batchError in
                if let batchError = batchError {
                    deletionErrors.append("Legacy accounts batch error: \(batchError.localizedDescription)")
                } else {
                    print("✅ Firebase: Deleted \(accounts.count) legacy account documents")
                }
                dispatchGroup.leave()
            }
        }
        
        // 5. Delete main user document: users/{userId}
        dispatchGroup.enter()
        print("🗑️ Firebase: Step 5 - Deleting main user document...")
        db.collection("users").document(userId).delete { error in
            if let error = error {
                deletionErrors.append("Main user document error: \(error.localizedDescription)")
            } else {
                deletedCounts["user_document"] = 1
                print("✅ Firebase: Deleted main user document")
            }
            dispatchGroup.leave()
        }
        
        // Wait for all deletions to complete
        dispatchGroup.notify(queue: .main) {
            if deletionErrors.isEmpty {
                let totalDeleted = deletedCounts.values.reduce(0, +)
                print("🎉 Firebase: COMPREHENSIVE DELETION COMPLETE for \(userName)")
                print("📊 Firebase: Deletion summary:")
                print("   🗂️ Nested transactions: \(deletedCounts["nested_transactions"] ?? 0)")
                print("   🖼️ Receipt images: \(deletedCounts["receipt_images"] ?? 0)")
                print("   🌐 Global transactions: \(deletedCounts["global_transactions"] ?? 0)")
                print("   📋 Legacy accounts: \(deletedCounts["legacy_accounts"] ?? 0)")
                print("   👤 User document: \(deletedCounts["user_document"] ?? 0)")
                print("   📈 Total items deleted: \(totalDeleted)")
                print("✅ Firebase: User \(userName) completely removed from Firebase")
                completion(.success(()))
            } else {
                let errorMessage = "Multiple deletion errors: \(deletionErrors.joined(separator: "; "))"
                print("❌ Firebase: COMPREHENSIVE DELETION FAILED for \(userName): \(errorMessage)")
                completion(.failure(NSError(domain: "ComprehensiveDeletionError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
            }
        }
        #else
        print("✅ Firebase: Simulated comprehensive user data deletion")
        completion(.success(()))
        #endif
    }
    
    /// Delete ALL users from Firebase (nuclear option)
    func deleteAllUsers(completion: @escaping (Result<Int, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        print("💥 Firebase: DELETING ALL USERS - Nuclear cleanup option")
        
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firebase: Failed to get users for deletion: \(error)")
                completion(.failure(error))
                return
            }
            
            let documents = snapshot?.documents ?? []
            print("💥 Firebase: Found \(documents.count) users to DELETE")
            
            guard !documents.isEmpty else {
                print("✅ Firebase: No users to delete")
                completion(.success(0))
                return
            }
            
            let batch = db.batch()
            for userDoc in documents {
                print("🗑️ Firebase: Deleting user: \(userDoc.documentID.prefix(8))")
                batch.deleteDocument(userDoc.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("❌ Firebase: Failed to delete all users: \(error)")
                    completion(.failure(error))
                } else {
                    print("✅ Firebase: Successfully deleted ALL \(documents.count) users")
                    completion(.success(documents.count))
                }
            }
        }
        #else
        completion(.success(0))
        #endif
    }
    
    /// Clean up fake user documents (debug method)
    func cleanupFakeUsers(keepOnlyUserId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        print("🧹 Firebase: Cleaning up fake user documents (keeping only \(keepOnlyUserId.prefix(8)))")
        
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firebase: Failed to get users for cleanup: \(error)")
                completion(.failure(error))
                return
            }
            
            let documents = snapshot?.documents ?? []
            let fakeUsers = documents.filter { $0.documentID != keepOnlyUserId }
            
            print("🧹 Firebase: Found \(documents.count) total users, \(fakeUsers.count) fake users to delete")
            
            guard !fakeUsers.isEmpty else {
                print("✅ Firebase: No fake users to clean up")
                completion(.success(0))
                return
            }
            
            let batch = db.batch()
            for fakeUser in fakeUsers {
                batch.deleteDocument(fakeUser.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("❌ Firebase: Failed to delete fake users: \(error)")
                    completion(.failure(error))
                } else {
                    print("✅ Firebase: Successfully deleted \(fakeUsers.count) fake user documents")
                    completion(.success(fakeUsers.count))
                }
            }
        }
        #else
        completion(.success(0))
        #endif
    }

    // MARK: - Receipt Image Management (Base64 encoding for Firestore)
    
    private func saveReceiptImage(_ image: UIImage, transactionId: String, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "ImageConversion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        let base64String = imageData.base64EncodedString()
        let imageRef = db.collection("users")
            .document(userId)
            .collection("receiptImages")
            .document(transactionId)
        
        imageRef.setData([
            "imageData": base64String,
            "createdAt": Date()
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
        #else
        completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1)))
        #endif
    }
    
    private func deleteReceiptImage(transactionId: String, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.success(())) // Silently succeed if Firebase not configured
            return
        }
        
        let imageRef = db.collection("users")
            .document(userId)
            .collection("receiptImages")
            .document(transactionId)
        
        imageRef.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
        #else
        completion(.success(()))
        #endif
    }

    // MARK: - Data Conversion Helpers
    
    /// Public method for TransactionSyncManager to access data conversion
    func convertTransactionToFirestoreData(_ transaction: Txn) throws -> [String: Any] {
        return try transactionToFirestoreData(transaction)
    }
    
    /// Public method for TransactionSyncManager to access data conversion
    func convertFirestoreDataToTransaction(_ data: [String: Any], transactionId: String, userId: String? = nil) throws -> Txn {
        return try firestoreDataToTransaction(data, transactionId: transactionId, userId: userId)
    }
    
    internal func transactionToFirestoreData(_ transaction: Txn) throws -> [String: Any] {
        #if canImport(FirebaseFirestore)
        var data: [String: Any] = [
            "id": transaction.id.uuidString,
            "userId": transaction.userId.uuidString,
            "category": transaction.category,
            "amount": transaction.amount,
            "date": Timestamp(date: transaction.date), // Convert Date to Firestore Timestamp
            "createdAt": Timestamp(date: transaction.createdAt), // Convert Date to Firestore Timestamp
            "hasReceiptImage": transaction.hasReceiptImage,
            "primaryCurrency": transaction.primaryCurrency.rawValue,
            "items": transaction.items.map { item in
                [
                    "description": item.description,
                    "quantity": item.quantity,
                    "unitPrice": item.unitPrice,
                    "totalPrice": item.totalPrice
                ]
            }
        ]
        #else
        var data: [String: Any] = [
            "id": transaction.id.uuidString,
            "userId": transaction.userId.uuidString,
            "category": transaction.category,
            "amount": transaction.amount,
            "date": transaction.date.timeIntervalSince1970, // Fallback for non-Firebase builds
            "createdAt": transaction.createdAt.timeIntervalSince1970, // Fallback for non-Firebase builds
            "hasReceiptImage": transaction.hasReceiptImage,
            "primaryCurrency": transaction.primaryCurrency.rawValue,
            "items": transaction.items.map { item in
                [
                    "description": item.description,
                    "quantity": item.quantity,
                    "unitPrice": item.unitPrice,
                    "totalPrice": item.totalPrice
                ]
            }
        ]
        #endif
        
        // Add optional fields
        if let categoryId = transaction.categoryId {
            data["categoryId"] = categoryId.uuidString
        }
        if let merchantName = transaction.merchantName {
            data["merchantName"] = merchantName
        }
        if let paymentMethod = transaction.paymentMethod {
            data["paymentMethod"] = paymentMethod
        }
        if let receiptNumber = transaction.receiptNumber {
            data["receiptNumber"] = receiptNumber
        }
        if let invoiceNumber = transaction.invoiceNumber {
            data["invoiceNumber"] = invoiceNumber
        }
        if let note = transaction.note {
            data["note"] = note
        }
        if let accountId = transaction.accountId {
            data["accountId"] = accountId.uuidString
        }
        if let originalAmount = transaction.originalAmount {
            data["originalAmount"] = originalAmount
        }
        if let originalCurrency = transaction.originalCurrency {
            data["originalCurrency"] = originalCurrency.rawValue
        }
        if let secondaryCurrency = transaction.secondaryCurrency {
            data["secondaryCurrency"] = secondaryCurrency.rawValue
        }
        if let exchangeRate = transaction.exchangeRate {
            data["exchangeRate"] = exchangeRate
        }
        if let secondaryAmount = transaction.secondaryAmount {
            data["secondaryAmount"] = secondaryAmount
        }
        if let secondaryExchangeRate = transaction.secondaryExchangeRate {
            data["secondaryExchangeRate"] = secondaryExchangeRate
        }
        
        return data
    }
    
    internal func firestoreDataToTransaction(_ data: [String: Any], transactionId: String, userId: String? = nil) throws -> Txn {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let category = data["category"] as? String,
              let amount = data["amount"] as? Double,
              let hasReceiptImage = data["hasReceiptImage"] as? Bool,
              let primaryCurrencyString = data["primaryCurrency"] as? String,
              let primaryCurrency = Currency(rawValue: primaryCurrencyString) else {
            throw NSError(domain: "DataConversion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing required transaction fields"])
        }
        
        // Get userId from data if stored, otherwise use provided userId or create new one
        let transactionUserId: UUID
        if let userIdString = data["userId"] as? String, let uid = UUID(uuidString: userIdString) {
            transactionUserId = uid
        } else if let providedUserId = userId, let uid = UUID(uuidString: providedUserId) {
            transactionUserId = uid
        } else {
            // Fallback - use current user if available
            transactionUserId = UserManager.shared.currentUser.id
        }
        
        // Handle date conversion (Firebase stores dates as Timestamp objects)
        // ❌ CRITICAL BUG FIX: Never use current time as fallback!
        let date: Date
        let createdAt: Date
        
        #if canImport(FirebaseFirestore)
        // Handle Firestore Timestamp objects
        if let timestamp = data["date"] as? Timestamp {
            date = timestamp.dateValue()
            print("✅ FirestoreService: Retrieved stored date from Timestamp: \(date)")
        } else if let storedDate = data["date"] as? Date {
            date = storedDate
            print("✅ FirestoreService: Retrieved stored date as Date: \(storedDate)")
        } else {
            print("🚨 FirestoreService: WARNING - 'date' field missing from Firebase document \(transactionId.prefix(8))")
            print("🔍 FirestoreService: Available fields: \(data.keys.sorted())")
            // Use epoch time instead of current time to make the problem obvious
            date = Date(timeIntervalSince1970: 0) // January 1, 1970
        }
        
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
            print("✅ FirestoreService: Retrieved stored createdAt from Timestamp: \(createdAt)")
        } else if let storedCreatedAt = data["createdAt"] as? Date {
            createdAt = storedCreatedAt
            print("✅ FirestoreService: Retrieved stored createdAt as Date: \(storedCreatedAt)")
        } else {
            print("🚨 FirestoreService: WARNING - 'createdAt' field missing from Firebase document \(transactionId.prefix(8))")
            print("🔍 FirestoreService: Available fields: \(data.keys.sorted())")
            // Use epoch time instead of current time to make the problem obvious
            createdAt = Date(timeIntervalSince1970: 0) // January 1, 1970
        }
        #else
        // Handle timestamp numbers for non-Firebase builds
        if let timestampInterval = data["date"] as? TimeInterval {
            date = Date(timeIntervalSince1970: timestampInterval)
            print("✅ FirestoreService: Retrieved stored date from timestamp: \(date)")
        } else if let storedDate = data["date"] as? Date {
            date = storedDate
            print("✅ FirestoreService: Retrieved stored date: \(storedDate)")
        } else {
            print("🚨 FirestoreService: WARNING - 'date' field missing from document \(transactionId.prefix(8))")
            date = Date(timeIntervalSince1970: 0)
        }
        
        if let timestampInterval = data["createdAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: timestampInterval)
            print("✅ FirestoreService: Retrieved stored createdAt from timestamp: \(createdAt)")
        } else if let storedCreatedAt = data["createdAt"] as? Date {
            createdAt = storedCreatedAt
            print("✅ FirestoreService: Retrieved stored createdAt: \(storedCreatedAt)")
        } else {
            print("🚨 FirestoreService: WARNING - 'createdAt' field missing from document \(transactionId.prefix(8))")
            createdAt = Date(timeIntervalSince1970: 0)
        }
        #endif
        
        let categoryId = (data["categoryId"] as? String).flatMap { UUID(uuidString: $0) }
        let merchantName = data["merchantName"] as? String
        let paymentMethod = data["paymentMethod"] as? String
        let receiptNumber = data["receiptNumber"] as? String
        let invoiceNumber = data["invoiceNumber"] as? String
        let note = data["note"] as? String
        let accountId = (data["accountId"] as? String).flatMap { UUID(uuidString: $0) }
        
        let originalAmount = data["originalAmount"] as? Double
        let originalCurrency = (data["originalCurrency"] as? String).flatMap { Currency(rawValue: $0) }
        let secondaryCurrency = (data["secondaryCurrency"] as? String).flatMap { Currency(rawValue: $0) }
        let exchangeRate = data["exchangeRate"] as? Double
        let secondaryAmount = data["secondaryAmount"] as? Double
        let secondaryExchangeRate = data["secondaryExchangeRate"] as? Double
        
        let itemsData = data["items"] as? [[String: Any]] ?? []
        let items = itemsData.compactMap { itemData -> ReceiptItem? in
            guard let description = itemData["description"] as? String,
                  let quantity = itemData["quantity"] as? Int,
                  let unitPrice = itemData["unitPrice"] as? Double,
                  let totalPrice = itemData["totalPrice"] as? Double else {
                return nil
            }
            return ReceiptItem(description: description, quantity: quantity, unitPrice: unitPrice, totalPrice: totalPrice)
        }
        
        return Txn(
            id: id,
            userId: transactionUserId,
            category: category,
            categoryId: categoryId,
            amount: amount,
            date: date,
            createdAt: createdAt,
            receiptImage: nil, // Will be loaded separately if needed
            hasReceiptImage: hasReceiptImage,
            merchantName: merchantName,
            paymentMethod: paymentMethod,
            receiptNumber: receiptNumber,
            invoiceNumber: invoiceNumber,
            items: items,
            note: note,
            accountId: accountId,
            originalAmount: originalAmount,
            originalCurrency: originalCurrency,
            primaryCurrency: primaryCurrency,
            secondaryCurrency: secondaryCurrency,
            exchangeRate: exchangeRate,
            secondaryAmount: secondaryAmount,
            secondaryExchangeRate: secondaryExchangeRate
        )
    }

    // MARK: - Legacy Accounts (keeping for backward compatibility)
    func createAccount(_ data: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        var ref: DocumentReference?
        ref = db.collection("accounts").addDocument(data: data) { error in
            if let error = error { completion(.failure(error)); return }
            completion(.success(ref?.documentID ?? ""))
        }
        #else
        completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1)))
        #endif
    }

    func fetchAccounts(for userId: String, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        db.collection("accounts").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error { completion(.failure(error)); return }
            let docs = snapshot?.documents.map { $0.data() } ?? []
            completion(.success(docs))
        }
        #else
        completion(.success([]))
        #endif
    }
    
    // MARK: - Enhanced Debug Methods
    
    /// Debug Firebase transaction documents to check for missing userId fields
    func debugUserIdFieldInFirebase(userId: String) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ FirestoreService: debugUserIdFieldInFirebase - Database not available")
            return
        }
        
        print("🔍 FirestoreService: DEBUGGING USERID FIELD in Firebase documents...")
        print("🆔 FirestoreService: Looking for user: \(userId.prefix(8))...")
        
        // Check the CORRECT location where app saves transactions: users/{userId}/transactions/
        db.collection("users")
            .document(userId)
            .collection("transactions")
            .order(by: "date", descending: true)
            .limit(to: 10)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ FirestoreService: Error fetching transaction documents: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("❌ FirestoreService: No documents found in transactions collection")
                    return
                }
                
                print("🔍 FirestoreService: Found \(documents.count) recent transaction documents")
                
                for (index, doc) in documents.enumerated() {
                    let data = doc.data()
                    let docId = doc.documentID
                    
                    print("📄 FirestoreService: Document \(index + 1) - ID: \(docId.prefix(8))...")
                    
                    // Check if userId field exists
                    if let docUserId = data["userId"] as? String {
                        print("   ✅ userId field FOUND: \(docUserId.prefix(8))...")
                        if docUserId == userId {
                            print("   🎯 MATCH! This document belongs to current user")
                        } else {
                            print("   👤 Different user: \(self.getUserName(for: docUserId))")
                        }
                    } else {
                        print("   ❌ userId field MISSING from document!")
                    }
                    
                    // Show other key fields for context
                    if let category = data["category"] as? String {
                        print("   📂 Category: \(category)")
                    }
                    if let amount = data["amount"] as? Double {
                        print("   💰 Amount: \(amount)")
                    }
                    if let merchantName = data["merchantName"] as? String {
                        print("   🏪 Merchant: \(merchantName)")
                    }
                    if let timestamp = data["date"] as? Timestamp {
                        print("   📅 Date: \(timestamp.dateValue())")
                    }
                    
                    print("   📋 All fields: \(data.keys.sorted())")
                    print("") // Empty line for readability
                }
                
                // Summary
                let documentsWithUserId = documents.filter { doc in
                    doc.data()["userId"] != nil
                }.count
                let documentsWithoutUserId = documents.count - documentsWithUserId
                
                print("📊 FirestoreService: USERID FIELD SUMMARY:")
                print("   ✅ Documents WITH userId: \(documentsWithUserId)")
                print("   ❌ Documents WITHOUT userId: \(documentsWithoutUserId)")
                print("   📝 Total documents checked: \(documents.count)")
                
                if documentsWithoutUserId > 0 {
                    print("🚨 FirestoreService: CRITICAL ISSUE - \(documentsWithoutUserId) documents missing userId field!")
                    print("🔧 FirestoreService: These documents won't be properly attributed to users")
                } else {
                    print("✅ FirestoreService: All nested documents have userId field - No issues found")
                }
                
                // ALSO check the global transactions collection
                print("\n🌐 FirestoreService: ALSO checking GLOBAL transactions collection...")
                db.collection("transactions")
                    .order(by: "date", descending: true)
                    .limit(to: 10)
                    .getDocuments { globalSnapshot, globalError in
                        if let globalError = globalError {
                            print("❌ FirestoreService: Error fetching global transaction documents: \(globalError)")
                            return
                        }
                        
                        guard let globalDocuments = globalSnapshot?.documents else {
                            print("❌ FirestoreService: No documents found in GLOBAL transactions collection")
                            return
                        }
                        
                        print("🔍 FirestoreService: Found \(globalDocuments.count) global transaction documents")
                        
                        let globalDocsWithUserId = globalDocuments.filter { doc in
                            doc.data()["userId"] != nil
                        }.count
                        let globalDocsWithoutUserId = globalDocuments.count - globalDocsWithUserId
                        
                        print("📊 FirestoreService: GLOBAL TRANSACTIONS SUMMARY:")
                        print("   ✅ Global documents WITH userId: \(globalDocsWithUserId)")
                        print("   ❌ Global documents WITHOUT userId: \(globalDocsWithoutUserId)")
                        print("   📝 Total global documents checked: \(globalDocuments.count)")
                        
                        if globalDocsWithoutUserId > 0 {
                            print("🚨 FirestoreService: GLOBAL COLLECTION ISSUE - \(globalDocsWithoutUserId) global documents missing userId field!")
                            print("🔧 FirestoreService: These are legacy documents that need cleanup or they're created by old code")
                        } else {
                            print("✅ FirestoreService: All global documents have userId field - Perfect!")
                        }
                    }
            }
        #else
        print("❌ FirestoreService: debugUserIdFieldInFirebase - Firebase not available")
        #endif
    }
    
    // MARK: - User Signup & Creation
    
    /// Generic user signup function for future use
    func signupUser(
        userId: String? = nil,
        name: String,
        email: String,
        primaryCurrency: String = "php",
        generateSampleData: Bool = false,
        sampleDataMonths: [DateComponents] = [],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        print("👤 FirestoreService: Creating user '\(name)' with signup function...")
        
        // Generate user ID if not provided
        let finalUserId = userId ?? UUID().uuidString
        let userUUID = UUID(uuidString: finalUserId)!
        
        // Create user document
        let userData: [String: Any] = [
            "id": finalUserId,
            "name": name,
            "email": email,
            "primaryCurrency": primaryCurrency,
            "signupDate": Date(),
            "createdAt": Date()
        ]
        
        print("📝 FirestoreService: User data to save: \(userData)")
        
        // Save user document
        db.collection("users").document(finalUserId).setData(userData) { userError in
            if let userError = userError {
                print("❌ FirestoreService: Failed to create user '\(name)': \(userError)")
                completion(.failure(userError))
                return
            }
            
            print("✅ FirestoreService: Created user '\(name)' successfully")
            
            // Generate sample data if requested
            if generateSampleData && !sampleDataMonths.isEmpty {
                let sampleTransactions = self.generateSampleTransactions(
                    userId: userUUID,
                    months: sampleDataMonths
                )
                
                print("📊 FirestoreService: Generated \(sampleTransactions.count) sample transactions for \(name)")
                
                // Save transactions in batches
                self.saveTransactionsBatch(transactions: sampleTransactions, userId: finalUserId) { batchResult in
                    switch batchResult {
                    case .success():
                        print("🎉 FirestoreService: Successfully created user '\(name)' with \(sampleTransactions.count) sample transactions!")
                        completion(.success(finalUserId))
                    case .failure(let error):
                        print("⚠️ FirestoreService: Created user '\(name)' but transaction save errors occurred: \(error)")
                        completion(.failure(error))
                    }
                }
            } else {
                print("✅ FirestoreService: User '\(name)' created without sample data")
                completion(.success(finalUserId))
            }
        }
        #else
        completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not available"])))
        #endif
    }
    
    /// Create Dante Cardines III user with sample transactions for September-October
    func createDanteUserWithSampleData(completion: @escaping (Result<Void, Error>) -> Void) {
        print("👤 FirestoreService: Creating Dante Cardines III user with sample data...")
        
        let september2024 = DateComponents(year: 2024, month: 9, day: 1)
        let october2024 = DateComponents(year: 2024, month: 10, day: 1)
        
        signupUser(
            userId: UserManager.shared.currentUser.id.uuidString, // Dynamic current user ID
            name: "Dante Cardines III",
            email: "dcardinesiii@gmail.com",
            primaryCurrency: "php",
            generateSampleData: true,
            sampleDataMonths: [september2024, october2024]
        ) { result in
            switch result {
            case .success(let userId):
                print("🎉 FirestoreService: Successfully created Dante Cardines III with ID: \(userId.prefix(8))...")
                completion(.success(()))
            case .failure(let error):
                print("❌ FirestoreService: Failed to create Dante Cardines III: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Save multiple transactions in batch with proper error handling
    private func saveTransactionsBatch(
        transactions: [Txn],
        userId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            completion(.failure(NSError(domain: "FirestoreUnavailable", code: -1)))
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var saveErrors: [Error] = []
        
        for transaction in transactions {
            dispatchGroup.enter()
            
            do {
                let transactionData = try self.transactionToFirestoreData(transaction)
                
                // Save to nested collection
                let nestedRef = db.collection("users")
                    .document(userId)
                    .collection("transactions")
                    .document(transaction.id.uuidString)
                
                nestedRef.setData(transactionData) { nestedError in
                    if let nestedError = nestedError {
                        print("❌ FirestoreService: Failed to save transaction \(transaction.id.uuidString.prefix(8)): \(nestedError)")
                        saveErrors.append(nestedError)
                        dispatchGroup.leave()
                    } else {
                        print("✅ FirestoreService: Saved transaction \(transaction.category) ₱\(transaction.amount)")
                        
                        // Also save to global collection
                        let globalRef = db.collection("transactions").document(transaction.id.uuidString)
                        globalRef.setData(transactionData) { globalError in
                            if let globalError = globalError {
                                print("⚠️ FirestoreService: Failed to save to global collection: \(globalError)")
                            }
                            dispatchGroup.leave()
                        }
                    }
                }
            } catch {
                print("❌ FirestoreService: Failed to convert transaction to Firestore data: \(error)")
                saveErrors.append(error)
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if saveErrors.isEmpty {
                completion(.success(()))
            } else {
                completion(.failure(saveErrors.first!))
            }
        }
        #endif
    }
    
    /// Generate sample transactions for specified months (generic)
    private func generateSampleTransactions(userId: UUID, months: [DateComponents]) -> [Txn] {
        let categories = ["Food", "Dining", "Transport", "Utilities & Bills", "Clothes", "Fun", "Personal", "Health"]
        let merchants = [
            "Food": ["SM Supermarket", "Robinsons", "Metro Mart", "Puregold"],
            "Dining": ["McDonald's", "Burger King", "Jollibee", "Starbucks", "Coffee Bean"],
            "Transport": ["Grab", "Taxi", "MRT", "Shell", "Petron"],
            "Utilities & Bills": ["PLDT", "Globe", "Meralco", "Manila Water"],
            "Clothes": ["Uniqlo", "H&M", "Zara", "Bench"],
            "Fun": ["Cinema", "Netflix", "Spotify", "Gaming"],
            "Personal": ["Salon", "Spa", "Watsons", "Mercury Drug"],
            "Health": ["Hospital", "Clinic", "Pharmacy", "Doctor"]
        ]
        
        let cal = Calendar.current
        var transactions: [Txn] = []
        
        // Generate transactions for each specified month
        for monthComponent in months {
            if let monthDate = cal.date(from: monthComponent) {
                let monthTransactions = generateTransactionsForMonth(
                    userId: userId,
                    month: monthDate,
                    categories: categories,
                    merchants: merchants,
                    transactionCount: Int.random(in: 10...15)
                )
                transactions.append(contentsOf: monthTransactions)
                
                print("📅 FirestoreService: Generated \(monthTransactions.count) transactions for \(monthComponent.month!)/\(monthComponent.year!)")
            }
        }
        
        // Add the Claude Pro transaction from sample data (for Dante specifically)
        if userId == UserManager.shared.currentUser.id {
            let claudeProTransaction = DummyDataGenerator.generateSampleReceiptTransaction()
            transactions.append(claudeProTransaction)
            print("📄 FirestoreService: Added Claude Pro receipt transaction for Dante")
        }
        
        return transactions.sorted { $0.date > $1.date }
    }
    
    /// Generate transactions for a specific month
    private func generateTransactionsForMonth(
        userId: UUID,
        month: Date,
        categories: [String],
        merchants: [String: [String]],
        transactionCount: Int
    ) -> [Txn] {
        let cal = Calendar.current
        let monthStart = cal.dateInterval(of: .month, for: month)?.start ?? month
        let daysInMonth = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        
        var transactions: [Txn] = []
        
        // Check if this is October 2024 - if so, make all dates "yesterday"
        let monthComponents = cal.dateComponents([.year, .month], from: month)
        let isOctober2024 = monthComponents.year == 2024 && monthComponents.month == 10
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        for _ in 0..<transactionCount {
            let transactionDate: Date
            
            if isOctober2024 {
                // 🔥 MAKE ALL OCTOBER 2024 TRANSACTIONS "YESTERDAY"
                let randomHour = Int.random(in: 7...23)
                let randomMinute = Int.random(in: 0...59)
                
                var yesterdayComponents = cal.dateComponents([.year, .month, .day], from: yesterday)
                yesterdayComponents.hour = randomHour
                yesterdayComponents.minute = randomMinute
                
                transactionDate = cal.date(from: yesterdayComponents) ?? yesterday
                print("🔥 FirestoreService: October 2024 transaction set to YESTERDAY: \(transactionDate)")
            } else {
                // Keep other months (September) as random dates in their respective month
                let randomDay = Int.random(in: 1...daysInMonth)
                let randomHour = Int.random(in: 7...23)
                let randomMinute = Int.random(in: 0...59)
                
                var dateComponents = cal.dateComponents([.year, .month], from: monthStart)
                dateComponents.day = randomDay
                dateComponents.hour = randomHour
                dateComponents.minute = randomMinute
                
                transactionDate = cal.date(from: dateComponents) ?? monthStart
            }
            
            // Use HARDCODED historical createdAt dates to eliminate ANY current time usage
            let hardcodedCreatedAtDates = [
                cal.date(from: DateComponents(year: 2024, month: 9, day: 25, hour: 14, minute: 30)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 9, day: 28, hour: 16, minute: 45)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 10, day: 2, hour: 10, minute: 15)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 10, day: 5, hour: 18, minute: 20)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 10, day: 8, hour: 12, minute: 10)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 10, day: 12, hour: 9, minute: 55)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 10, day: 15, hour: 15, minute: 30)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 10, day: 18, hour: 11, minute: 40)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 10, day: 22, hour: 17, minute: 25)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 10, day: 25, hour: 13, minute: 50)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 10, day: 28, hour: 19, minute: 15)) ?? transactionDate,
                cal.date(from: DateComponents(year: 2024, month: 10, day: 31, hour: 16, minute: 35)) ?? transactionDate
            ]
            let createdAtWithMinutes = hardcodedCreatedAtDates.randomElement() ?? transactionDate
            
            // 20% chance for income transactions
            let isIncome = Int.random(in: 1...100) <= 20
            
            let category: String
            let merchant: String
            let amount: Double
            
            if isIncome {
                let incomeCategories = ["Salary", "Business Income", "Freelance", "Investment"]
                let incomeMerchants = [
                    "Salary": ["Tech Company", "Consulting Firm", "Digital Agency"],
                    "Business Income": ["Client Project", "App Revenue", "Consulting"],
                    "Freelance": ["Freelance Client", "Design Work", "Development"],
                    "Investment": ["Stock Dividends", "Crypto", "Rental Income"]
                ]
                
                category = incomeCategories.randomElement()!
                let merchantList = incomeMerchants[category] ?? ["Income Source"]
                merchant = merchantList.randomElement()!
                amount = Double(Int.random(in: 2000...25000)) // Positive for income
            } else {
                category = categories.randomElement()!
                let merchantList = merchants[category] ?? ["Unknown Merchant"]
                merchant = merchantList.randomElement()!
                amount = -Double(Int.random(in: 75...2500)) // Negative for expense
            }
            
            let transaction = Txn(
                userId: userId,
                category: category,
                amount: amount,
                date: transactionDate,
                createdAt: createdAtWithMinutes, // ✅ Now uses historical timestamp!
                merchantName: merchant
            )
            
            transactions.append(transaction)
        }
        
        return transactions
    }
    
    // MARK: - Connection Testing
    
    func testConnection(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔥 FirestoreService: Testing connection to Firebase...")
        
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ FirestoreService: Cannot test connection - Firestore not available")
            completion(.failure(NSError(domain: "FirestoreService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        // Perform a simple read operation to test connectivity
        let startTime = Date()
        db.collection("_connection_test").limit(to: 1).getDocuments { snapshot, error in
            let duration = Date().timeIntervalSince(startTime)
            print("🔥 FirestoreService: Connection test completed in \(String(format: "%.2f", duration))s")
            
            if let error = error {
                print("❌ FirestoreService: Connection test failed - \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("✅ FirestoreService: Connection test successful - Firebase backend reachable")
                completion(.success(()))
            }
        }
        #else
        print("⚠️ FirestoreService: Firebase not available - using mock success")
        completion(.success(()))
        #endif
    }
    
    // MARK: - Privacy-First Data Methods
    
    /// Save user profile (non-sensitive data) to cloud
    func saveUserProfile(_ profile: UserProfile, completion: @escaping (Bool) -> Void) {
        print("👤 FirestoreService: Saving user profile to cloud...")
        
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ FirestoreService: Cannot save profile - Firestore not available")
            completion(false)
            return
        }
        
        do {
            let profileData = try JSONEncoder().encode(profile)
            let profileDict = try JSONSerialization.jsonObject(with: profileData) as? [String: Any] ?? [:]
            
            db.collection("user_profiles").document(profile.firebaseUID).setData(profileDict) { error in
                if let error = error {
                    print("❌ FirestoreService: Failed to save profile - \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ FirestoreService: User profile saved successfully")
                    completion(true)
                }
            }
        } catch {
            print("❌ FirestoreService: Failed to encode profile - \(error)")
            completion(false)
        }
        #else
        print("⚠️ FirestoreService: Firebase not available - profile not saved")
        completion(false)
        #endif
    }
    
    /// Load user profile from cloud
    func fetchUserProfile(userId: String, completion: @escaping (Result<UserProfile?, Error>) -> Void) {
        print("👤 FirestoreService: Fetching user profile from cloud...")
        
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ FirestoreService: Cannot fetch profile - Firestore not available")
            completion(.failure(NSError(domain: "FirestoreService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        db.collection("user_profiles").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("❌ FirestoreService: Error fetching profile - \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, document.exists, let data = document.data() else {
                print("📄 FirestoreService: No profile found for user")
                completion(.success(nil))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let profile = try JSONDecoder().decode(UserProfile.self, from: jsonData)
                print("✅ FirestoreService: User profile loaded successfully")
                completion(.success(profile))
            } catch {
                print("❌ FirestoreService: Failed to decode profile - \(error)")
                completion(.failure(error))
            }
        }
        #else
        print("⚠️ FirestoreService: Firebase not available - returning nil profile")
        completion(.success(nil))
        #endif
    }
    
    /// Save encrypted financial data (optional backup)
    func saveEncryptedFinancialData(userId: String, encryptedData: Data, completion: @escaping (Bool) -> Void) {
        print("🔒 FirestoreService: Saving encrypted financial backup...")
        
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ FirestoreService: Cannot save backup - Firestore not available")
            completion(false)
            return
        }
        
        let backupData: [String: Any] = [
            "encryptedData": encryptedData.base64EncodedString(),
            "backupDate": Timestamp(date: Date()),
            "version": "1.0"
        ]
        
        db.collection("financial_backups").document(userId).setData(backupData) { error in
            if let error = error {
                print("❌ FirestoreService: Failed to save backup - \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ FirestoreService: Encrypted financial backup saved")
                completion(true)
            }
        }
        #else
        print("⚠️ FirestoreService: Firebase not available - backup not saved")
        completion(false)
        #endif
    }
    
    /// Load encrypted financial data (optional backup)
    func loadEncryptedFinancialData(userId: String, completion: @escaping (Result<Data, Error>) -> Void) {
        print("🔒 FirestoreService: Loading encrypted financial backup...")
        
        #if canImport(FirebaseFirestore)
        guard let db = db else {
            print("❌ FirestoreService: Cannot load backup - Firestore not available")
            completion(.failure(NSError(domain: "FirestoreService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        
        db.collection("financial_backups").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("❌ FirestoreService: Error loading backup - \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, 
                  document.exists,
                  let data = document.data(),
                  let encryptedString = data["encryptedData"] as? String,
                  let encryptedData = Data(base64Encoded: encryptedString) else {
                print("📄 FirestoreService: No financial backup found")
                completion(.failure(NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No backup found"])))
                return
            }
            
            print("✅ FirestoreService: Encrypted financial backup loaded")
            completion(.success(encryptedData))
        }
        #else
        print("⚠️ FirestoreService: Firebase not available - cannot load backup")
        completion(.failure(NSError(domain: "FirestoreService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase not available"])))
        #endif
    }
}




