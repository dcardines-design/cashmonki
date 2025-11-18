import Foundation
import Firebase
import FirebaseFirestore

class FirebaseSearchHelper {
    
    static func searchForChichaSenTransaction() {
        print("🔍 Starting Firebase database structure exploration...")
        
        let userId = UserManager.shared.currentUser.id.uuidString
        let db = Firestore.firestore()
        
        // First, check if the user document exists
        db.collection("users").document(userId).getDocument { userSnapshot, error in
            if let error = error {
                print("❌ Error checking user document: \(error.localizedDescription)")
                return
            }
            
            if let userDoc = userSnapshot, userDoc.exists {
                print("✅ User document exists in Firebase")
                let userData = userDoc.data()
                print("📊 User document data keys: \(userData?.keys.sorted() ?? [])")
                
                // Check what subcollections exist under this user
                db.collection("users").document(userId).collection("transactions").getDocuments { txnSnapshot, txnError in
                    if let txnError = txnError {
                        print("❌ Error checking transactions: \(txnError.localizedDescription)")
                        
                        // Try alternative collection structures
                        print("🔍 Trying alternative: direct transactions collection...")
                        FirebaseSearchHelper.checkDirectTransactionsCollection(db: db, userId: userId)
                        return
                    }
                    
                    if let txnDocs = txnSnapshot?.documents, !txnDocs.isEmpty {
                        print("✅ Found \(txnDocs.count) transactions in users/\(userId)/transactions")
                        FirebaseSearchHelper.searchInTransactions(documents: txnDocs)
                    } else {
                        print("❌ No transactions found in users/\(userId)/transactions")
                        print("🔍 Checking alternative collection structures...")
                        FirebaseSearchHelper.checkDirectTransactionsCollection(db: db, userId: userId)
                    }
                }
            } else {
                print("❌ User document doesn't exist in Firebase")
                print("🔍 Checking what collections exist in Firebase...")
                FirebaseSearchHelper.checkRootCollections(db: db)
            }
        }
    }
    
    static func checkDirectTransactionsCollection(db: Firestore, userId: String) {
        // Check if transactions are stored directly in a transactions collection
        db.collection("transactions").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error checking direct transactions: \(error.localizedDescription)")
                return
            }
            
            if let docs = snapshot?.documents, !docs.isEmpty {
                print("✅ Found \(docs.count) transactions in direct transactions collection")
                FirebaseSearchHelper.searchInTransactions(documents: docs)
            } else {
                print("❌ No transactions found in direct transactions collection either")
                print("🔍 Let's see what's actually in Firebase...")
                FirebaseSearchHelper.checkAllCollections(db: db)
            }
        }
    }
    
    static func checkRootCollections(db: Firestore) {
        // List all root collections
        db.collectionGroup("transactions").limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error checking collection groups: \(error.localizedDescription)")
                return
            }
            
            if let docs = snapshot?.documents, !docs.isEmpty {
                print("✅ Found transactions using collection group query")
                let firstDoc = docs[0]
                print("📍 Sample transaction path: \(firstDoc.reference.path)")
            } else {
                print("❌ No transactions found anywhere in Firebase")
            }
        }
    }
    
    static func checkAllCollections(db: Firestore) {
        // Check common collection names
        let possibleCollections = ["transactions", "receipts", "expenses", "data"]
        
        for collectionName in possibleCollections {
            db.collection(collectionName).limit(to: 1).getDocuments { snapshot, error in
                if let docs = snapshot?.documents, !docs.isEmpty {
                    print("✅ Found data in collection: \(collectionName)")
                    print("📊 Sample document keys: \(docs[0].data().keys.sorted())")
                }
            }
        }
    }
    
    static func searchInTransactions(documents: [QueryDocumentSnapshot]) {
        print("🔍 Searching \(documents.count) transactions for Chicha Sen ₱150...")
        
        var chichaSenTransactions: [(String, Double, String, String)] = []
        var amount150Transactions: [(String, Double, String, String)] = []
        
        for document in documents {
            let data = document.data()
            print("📄 Transaction data keys: \(data.keys.sorted())")
            
            let merchant = data["merchant"] as? String ?? ""
            let amount = data["amount"] as? Double ?? 0.0
            let category = data["category"] as? String ?? ""
            let createdAt = data["createdAt"] as? String ?? ""
            
            print("   Transaction: \(merchant) - ₱\(amount) (\(category))")
            
            // Check for Chicha Sen
            if merchant.lowercased().contains("chicha sen") || 
               category.lowercased().contains("chicha sen") {
                chichaSenTransactions.append((merchant, amount, category, createdAt))
                print("🎯 FOUND CHICHA SEN: \(merchant) - ₱\(amount) (\(category)) on \(createdAt)")
            }
            
            // Check for ₱150 amount
            if abs(amount - Double(150.0)) < Double(0.01) {
                amount150Transactions.append((merchant, amount, category, createdAt))
                print("💰 FOUND ₱150: \(merchant) - ₱\(amount) (\(category)) on \(createdAt)")
            }
        }
        
        // Final results
        print("\n📋 SEARCH RESULTS:")
        print("   Chicha Sen transactions found: \(chichaSenTransactions.count)")
        print("   ₱150 transactions found: \(amount150Transactions.count)")
        
        // Check for exact match
        let exactMatches = chichaSenTransactions.filter { abs($0.1 - Double(150.0)) < Double(0.01) }
        if !exactMatches.isEmpty {
            print("✅ FOUND EXACT MATCH: Chicha Sen ₱150 transaction!")
            for match in exactMatches {
                print("   📍 \(match.0) - ₱\(match.1) (\(match.2)) on \(match.3)")
            }
        } else {
            print("❌ No exact Chicha Sen ₱150 transaction found")
        }
    }
    
    static func quickSearchForChichaSen() {
        print("🚀 Quick Firebase search for Chicha Sen...")
        searchForChichaSenTransaction()
    }
    
    static func debugAllRecentTransactions() {
        print("🔍 Debugging all recent transactions...")
        
        let userId = UserManager.shared.currentUser.id.uuidString
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).collection("transactions")
            .order(by: "createdAt", descending: true)
            .limit(to: 10)
            .getDocuments { snapshot, error in
                
                if let error = error {
                    print("❌ Firebase debug error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("❌ No recent transactions found")
                    return
                }
                
                print("📊 Last 10 transactions in Firebase:")
                for (index, document) in documents.enumerated() {
                    let data = document.data()
                    let merchant = data["merchant"] as? String ?? "Unknown"
                    let amount = data["amount"] as? Double ?? 0.0
                    let category = data["category"] as? String ?? "Unknown"
                    let createdAt = data["createdAt"] as? String ?? "Unknown"
                    
                    print("   \(index + 1). \(merchant) - ₱\(amount) (\(category)) on \(createdAt)")
                }
            }
    }
    
    func comprehensiveChichaSenSearch(completion: @escaping (Bool) -> Void) {
        print("🔍 Starting comprehensive Chicha Sen search...")
        
        let userId = UserManager.shared.currentUser.id.uuidString
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).collection("transactions").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error searching for Chicha Sen: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("❌ No transactions found")
                completion(false)
                return
            }
            
            print("🔍 Searching \(documents.count) transactions for Chicha Sen ₱150...")
            
            for document in documents {
                let data = document.data()
                let merchant = data["merchant"] as? String ?? ""
                let amount = data["amount"] as? Double ?? 0.0
                
                if merchant.lowercased().contains("chicha sen") && abs(amount - 150.0) < 0.01 {
                    print("✅ Found Chicha Sen ₱150 transaction!")
                    completion(true)
                    return
                }
            }
            
            print("❌ Chicha Sen ₱150 transaction not found")
            completion(false)
        }
    }
}