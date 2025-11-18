//
//  PrivacyDataManager.swift
//  CashMonki
//
//  Created by Claude on 1/27/25.
//

import Foundation
import SwiftUI

/// Privacy-first data manager that separates cloud and local data
/// Cloud: Only profile data (name, email, preferences, subscription)
/// Local: All financial data (transactions, accounts, balances)
class PrivacyDataManager: ObservableObject {
    static let shared = PrivacyDataManager()
    
    // MARK: - Published Properties
    
    @Published var userProfile: UserProfile?
    @Published var financialData: LocalFinancialData?
    @Published var isLoading = false
    @Published var error: String?
    
    // MARK: - Private Properties
    
    private let firestore = FirestoreService.shared
    private let localStorageKey = "LocalFinancialData"
    
    private init() {
        print("🔒 PrivacyDataManager: Initialized - ready for privacy-first data management")
    }
    
    // MARK: - Public Interface
    
    /// Setup user data after authentication
    func setupUser(from authenticatedUser: AuthenticatedUser, completion: @escaping (Bool) -> Void) {
        print("🔒 PrivacyDataManager: Setting up user data for \(authenticatedUser.email)")
        
        // Create user profile for cloud storage
        let profile = UserProfile(
            firebaseUID: authenticatedUser.firebaseUID,
            name: authenticatedUser.name,
            email: authenticatedUser.email,
            createdAt: authenticatedUser.createdAt
        )
        
        // Try to load existing profile from cloud
        loadUserProfile(firebaseUID: authenticatedUser.firebaseUID) { [weak self] cloudProfile in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Use cloud profile if exists, otherwise create new
                self.userProfile = cloudProfile ?? profile
                
                // Load local financial data
                self.loadLocalFinancialData()
                
                // If no financial data exists, create default
                if self.financialData == nil {
                    self.createDefaultFinancialData()
                }
                
                // Save profile to cloud if it's new
                if cloudProfile == nil {
                    self.saveUserProfile { success in
                        print(success ? "✅ New user profile saved to cloud" : "❌ Failed to save new profile")
                    }
                }
                
                completion(true)
            }
        }
    }
    
    /// Get user's total balance across all accounts
    var totalBalance: Double {
        return financialData?.totalBalance ?? 0
    }
    
    /// Get accounts (wallets)
    var accounts: [AccountData] {
        return financialData?.accounts ?? []
    }
    
    /// Get transactions
    var transactions: [Txn] {
        return financialData?.transactions ?? []
    }
    
    // MARK: - Financial Data Management (Local Only)
    
    func addTransaction(_ transaction: Txn) {
        guard var financial = financialData else { return }
        
        financial.addTransaction(transaction)
        financialData = financial
        saveLocalFinancialData()
        
        print("💰 PrivacyDataManager: Transaction added locally (NOT synced to cloud)")
    }
    
    func removeTransaction(withId id: UUID) {
        guard var financial = financialData else { return }
        
        financial.removeTransaction(withId: id)
        financialData = financial
        saveLocalFinancialData()
        
        print("💰 PrivacyDataManager: Transaction removed locally")
    }
    
    func updateTransaction(_ transaction: Txn) {
        guard var financial = financialData else { return }
        
        financial.updateTransaction(transaction)
        financialData = financial
        saveLocalFinancialData()
        
        print("💰 PrivacyDataManager: Transaction updated locally")
    }
    
    func addAccount(_ account: AccountData) {
        guard var financial = financialData else { return }
        
        financial.addAccount(account)
        financialData = financial
        saveLocalFinancialData()
        
        print("🏦 PrivacyDataManager: Account added locally (NOT synced to cloud)")
    }
    
    func removeAccount(withId accountId: UUID, reassignToAccountId: UUID? = nil) {
        guard var financial = financialData else { return }
        
        financial.removeAccount(withId: accountId, reassignToAccountId: reassignToAccountId)
        financialData = financial
        saveLocalFinancialData()
        
        print("🏦 PrivacyDataManager: Account removed locally")
    }
    
    // MARK: - Profile Data Management (Cloud Synced)
    
    func updateUserProfile(name: String? = nil, preferredCurrency: Currency? = nil, enableCloudBackup: Bool? = nil) {
        guard var profile = userProfile else { return }
        
        if let name = name { profile.name = name }
        if let currency = preferredCurrency { profile.preferredCurrency = currency }
        if let backup = enableCloudBackup { profile.enableCloudBackup = backup }
        
        profile.updatedAt = Date()
        userProfile = profile
        
        // Sync profile changes to cloud
        saveUserProfile { success in
            print(success ? "✅ Profile updated in cloud" : "❌ Failed to update profile in cloud")
        }
        
        print("👤 PrivacyDataManager: Profile updated and synced to cloud")
    }
    
    // MARK: - Optional Cloud Backup (User Controlled)
    
    func backupFinancialDataToCloud(completion: @escaping (Bool) -> Void) {
        guard let profile = userProfile, profile.enableCloudBackup else {
            print("🔒 PrivacyDataManager: Cloud backup disabled by user")
            completion(false)
            return
        }
        
        guard let financial = financialData else {
            completion(false)
            return
        }
        
        print("☁️ PrivacyDataManager: Backing up financial data to cloud (user enabled)")
        
        // Encrypt financial data before uploading
        let encryptedData = encryptFinancialData(financial)
        
        firestore.saveEncryptedFinancialData(
            userId: profile.firebaseUID,
            encryptedData: encryptedData
        ) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    var updatedFinancial = financial
                    updatedFinancial.lastBackupDate = Date()
                    self?.financialData = updatedFinancial
                    self?.saveLocalFinancialData()
                    print("✅ Financial data backed up to cloud")
                } else {
                    print("❌ Failed to backup financial data")
                }
                completion(success)
            }
        }
    }
    
    func restoreFinancialDataFromCloud(completion: @escaping (Bool) -> Void) {
        guard let profile = userProfile else {
            completion(false)
            return
        }
        
        print("☁️ PrivacyDataManager: Restoring financial data from cloud backup")
        
        firestore.loadEncryptedFinancialData(userId: profile.firebaseUID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let encryptedData):
                    if let decryptedData = self?.decryptFinancialData(encryptedData) {
                        self?.financialData = decryptedData
                        self?.saveLocalFinancialData()
                        print("✅ Financial data restored from cloud")
                        completion(true)
                    } else {
                        print("❌ Failed to decrypt financial data")
                        completion(false)
                    }
                case .failure(let error):
                    print("❌ Failed to load financial data from cloud: \(error)")
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Local Storage
    
    private func loadLocalFinancialData() {
        guard let profile = userProfile else { return }
        
        if let data = UserDefaults.standard.data(forKey: "\(localStorageKey)_\(profile.id.uuidString)"),
           let decoded = try? JSONDecoder().decode(LocalFinancialData.self, from: data) {
            financialData = decoded
            print("📱 PrivacyDataManager: Loaded financial data from local storage")
        } else {
            print("📱 PrivacyDataManager: No local financial data found")
        }
    }
    
    private func saveLocalFinancialData() {
        guard let profile = userProfile, let financial = financialData else { return }
        
        if let encoded = try? JSONEncoder().encode(financial) {
            UserDefaults.standard.set(encoded, forKey: "\(localStorageKey)_\(profile.id.uuidString)")
            print("📱 PrivacyDataManager: Financial data saved locally")
        }
    }
    
    private func createDefaultFinancialData() {
        guard let profile = userProfile else { return }
        
        // Extract first name for personalized wallet name
        let firstName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
            .first ?? profile.name
        
        let walletName = firstName.isEmpty ? "My Wallet" : "\(firstName)'s Wallet"
        
        // Create default wallet
        let defaultWallet = AccountData(
            id: UUID(), // Always use unique UUIDs
            name: walletName,
            type: .personal,
            currency: profile.preferredCurrency,
            isDefault: true
        )
        
        financialData = LocalFinancialData(
            userId: profile.id,
            accounts: [defaultWallet]
        )
        
        saveLocalFinancialData()
        print("🏦 PrivacyDataManager: Created default financial data")
    }
    
    // MARK: - Cloud Profile Storage
    
    private func loadUserProfile(firebaseUID: String, completion: @escaping (UserProfile?) -> Void) {
        firestore.fetchUserProfile(userId: firebaseUID) { result in
            switch result {
            case .success(let profile):
                completion(profile)
            case .failure:
                completion(nil)
            }
        }
    }
    
    private func saveUserProfile(completion: @escaping (Bool) -> Void) {
        guard let profile = userProfile else {
            completion(false)
            return
        }
        
        firestore.saveUserProfile(profile) { success in
            completion(success)
        }
    }
    
    // MARK: - Encryption (Placeholder)
    
    private func encryptFinancialData(_ data: LocalFinancialData) -> Data {
        // TODO: Implement proper encryption using CryptoKit
        // For now, just use JSON encoding
        return (try? JSONEncoder().encode(data)) ?? Data()
    }
    
    private func decryptFinancialData(_ data: Data) -> LocalFinancialData? {
        // TODO: Implement proper decryption using CryptoKit
        // For now, just use JSON decoding
        return try? JSONDecoder().decode(LocalFinancialData.self, from: data)
    }
    
    // MARK: - Migration from Legacy UserData
    
    func migrateFromLegacyUserData(_ legacy: UserData) {
        print("🔄 PrivacyDataManager: Migrating from legacy UserData")
        
        // Create profile from legacy data
        let profile = UserProfile(
            id: legacy.id,
            firebaseUID: legacy.id.uuidString, // Fallback if no Firebase UID
            name: legacy.name,
            email: legacy.email,
            createdAt: legacy.createdAt,
            updatedAt: legacy.updatedAt
        )
        
        // Create financial data from legacy data
        let financial = LocalFinancialData(
            userId: legacy.id,
            transactions: legacy.transactions,
            accounts: legacy.accounts,
            createdAt: legacy.createdAt,
            updatedAt: legacy.updatedAt
        )
        
        userProfile = profile
        financialData = financial
        
        // Save both
        saveLocalFinancialData()
        saveUserProfile { success in
            print(success ? "✅ Migration completed" : "❌ Migration failed")
        }
    }
}