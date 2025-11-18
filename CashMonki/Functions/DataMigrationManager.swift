//
//  DataMigrationManager.swift
//  CashMonki
//
//  Created by Claude on 1/27/25.
//

import Foundation
import SwiftUI

/// Privacy-first data migration manager with rollback capabilities
/// Handles "big bang" migration from legacy UserData to UserProfile + LocalFinancialData
/// Ensures data integrity and provides safety mechanisms for failed migrations
class DataMigrationManager: ObservableObject {
    static let shared = DataMigrationManager()
    
    // MARK: - Published Properties
    
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus: MigrationStatus = .notStarted
    @Published var migrationStep: String = ""
    @Published var migrationError: String?
    @Published var isRollingBack: Bool = false
    
    // MARK: - Private Properties
    
    private let backupStorageKey = "DataMigration_Backup"
    private let migrationVersionKey = "DataMigration_Version"
    private let currentMigrationVersion = "1.0.0"
    private var migrationStartTime: Date?
    private var backupData: Data?
    
    private init() {
        print("🔄 DataMigrationManager: Initialized - ready for privacy-first migration")
    }
    
    // MARK: - Public Interface
    
    /// Check if migration is needed
    func migrationNeeded() -> Bool {
        let currentVersion = UserDefaults.standard.string(forKey: migrationVersionKey)
        let hasLegacyData = UserDefaults.standard.data(forKey: "UserData") != nil
        
        print("🔍 Migration Check: Version=\(currentVersion ?? "none"), HasLegacy=\(hasLegacyData)")
        
        return currentVersion != currentMigrationVersion && hasLegacyData
    }
    
    /// Get migration requirements and data assessment
    func assessMigration() -> MigrationAssessment {
        guard let legacyData = loadLegacyUserData() else {
            return MigrationAssessment(
                canMigrate: false,
                reason: "No legacy data found",
                estimatedTime: 0,
                dataSize: 0,
                transactionCount: 0,
                accountCount: 0
            )
        }
        
        let transactionCount = legacyData.transactions.count
        let accountCount = legacyData.accounts.count
        let estimatedTime = calculateMigrationTime(transactions: transactionCount, accounts: accountCount)
        
        return MigrationAssessment(
            canMigrate: true,
            reason: "Legacy data ready for migration",
            estimatedTime: estimatedTime,
            dataSize: estimateDataSize(userData: legacyData),
            transactionCount: transactionCount,
            accountCount: accountCount
        )
    }
    
    /// Execute complete privacy-first migration with rollback safety
    func executeMigration(completion: @escaping (Bool, String?) -> Void) {
        guard migrationStatus != .inProgress else {
            completion(false, "Migration already in progress")
            return
        }
        
        guard migrationNeeded() else {
            completion(true, "No migration needed")
            return
        }
        
        print("🚀 DataMigrationManager: Starting privacy-first migration")
        
        migrationStartTime = Date()
        
        DispatchQueue.main.async { [weak self] in
            self?.migrationStatus = .inProgress
            self?.migrationProgress = 0.0
            self?.migrationError = nil
            self?.isRollingBack = false
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performMigration(completion: completion)
        }
    }
    
    /// Force rollback to previous state
    func rollbackMigration(completion: @escaping (Bool, String?) -> Void) {
        print("⏪ DataMigrationManager: Rolling back migration")
        
        DispatchQueue.main.async { [weak self] in
            self?.isRollingBack = true
            self?.migrationStep = "Rolling back changes..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performRollback(completion: completion)
        }
    }
    
    /// Clear migration data and reset state
    func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationVersionKey)
        UserDefaults.standard.removeObject(forKey: backupStorageKey)
        
        DispatchQueue.main.async { [weak self] in
            self?.migrationStatus = .notStarted
            self?.migrationProgress = 0.0
            self?.migrationError = nil
            self?.migrationStep = ""
            self?.isRollingBack = false
        }
        
        print("🔄 Migration state reset")
    }
    
    // MARK: - Private Migration Logic
    
    private func performMigration(completion: @escaping (Bool, String?) -> Void) {
        do {
            // Step 1: Create backup (5%)
            try createBackup()
            updateProgress(0.05, step: "Backup created")
            
            // Step 2: Load and validate legacy data (15%)
            guard let legacyData = loadLegacyUserData() else {
                throw MigrationError.noLegacyData
            }
            updateProgress(0.15, step: "Legacy data loaded")
            
            // Step 3: Validate data integrity (25%)
            try validateLegacyData(legacyData)
            updateProgress(0.25, step: "Data validation complete")
            
            // Step 4: Create new UserProfile (35%)
            let userProfile = try createUserProfile(from: legacyData)
            updateProgress(0.35, step: "User profile created")
            
            // Step 5: Create LocalFinancialData with sync metadata (60%)
            let financialData = try createLocalFinancialData(from: legacyData, userId: userProfile.id)
            updateProgress(0.60, step: "Financial data migrated")
            
            // Step 6: Save new data structures (80%)
            try saveNewDataStructures(profile: userProfile, financial: financialData)
            updateProgress(0.80, step: "New data saved")
            
            // Step 7: Validate migration success (90%)
            try validateMigration(profile: userProfile, financial: financialData, original: legacyData)
            updateProgress(0.90, step: "Migration validated")
            
            // Step 8: Cleanup and finalize (100%)
            finalizeMigration()
            updateProgress(1.0, step: "Migration complete")
            
            let duration = Date().timeIntervalSince(migrationStartTime ?? Date())
            print("✅ Migration completed successfully in \(String(format: "%.1f", duration))s")
            
            DispatchQueue.main.async {
                completion(true, nil)
            }
            
        } catch {
            print("❌ Migration failed: \(error)")
            
            DispatchQueue.main.async { [weak self] in
                self?.migrationStatus = .failed
                self?.migrationError = error.localizedDescription
            }
            
            // Attempt automatic rollback
            performRollback { success, rollbackError in
                let errorMessage = success ? 
                    "Migration failed but rollback successful: \(error.localizedDescription)" :
                    "Migration failed and rollback failed: \(error.localizedDescription). \(rollbackError ?? "")"
                completion(false, errorMessage)
            }
        }
    }
    
    private func createBackup() throws {
        guard let legacyData = UserDefaults.standard.data(forKey: "UserData") else {
            throw MigrationError.backupFailed("No legacy data to backup")
        }
        
        // Create comprehensive backup including timestamps
        let backup = MigrationBackup(
            legacyUserData: legacyData,
            backupDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            deviceInfo: DeviceInfo.current()
        )
        
        guard let backupData = try? JSONEncoder().encode(backup) else {
            throw MigrationError.backupFailed("Could not encode backup")
        }
        
        UserDefaults.standard.set(backupData, forKey: backupStorageKey)
        self.backupData = backupData
        
        print("💾 Backup created (\(backupData.count) bytes)")
    }
    
    private func loadLegacyUserData() -> UserData? {
        guard let data = UserDefaults.standard.data(forKey: "UserData"),
              let userData = try? JSONDecoder().decode(UserData.self, from: data) else {
            return nil
        }
        return userData
    }
    
    private func validateLegacyData(_ userData: UserData) throws {
        // Validate essential fields
        if userData.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw MigrationError.invalidData("User name is empty")
        }
        
        if userData.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw MigrationError.invalidData("User email is empty")
        }
        
        // Validate transactions
        for transaction in userData.transactions {
            if transaction.amount.isNaN || transaction.amount.isInfinite {
                throw MigrationError.invalidData("Transaction has invalid amount")
            }
            
            if transaction.category.isEmpty {
                throw MigrationError.invalidData("Transaction has empty category")
            }
        }
        
        // Validate accounts
        for account in userData.accounts {
            if account.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw MigrationError.invalidData("Account has empty name")
            }
        }
        
        print("✅ Legacy data validation passed")
    }
    
    private func createUserProfile(from userData: UserData) throws -> UserProfile {
        // Generate Firebase UID or use existing one
        let firebaseUID = userData.id.uuidString // For now, use UUID as fallback
        
        let profile = UserProfile(
            id: userData.id,
            firebaseUID: firebaseUID,
            name: userData.name,
            email: userData.email,
            createdAt: userData.createdAt,
            updatedAt: Date(), // Migration timestamp
            preferredCurrency: .php, // Default, could be enhanced from legacy data
            enableCloudBackup: false, // Privacy-first: default to local-only
            subscriptionTier: .free,
            languageCode: "en"
        )
        
        print("👤 User profile created for \(profile.name)")
        return profile
    }
    
    private func createLocalFinancialData(from userData: UserData, userId: UUID) throws -> LocalFinancialData {
        // Migrate transactions with sync metadata
        var migratedTransactions: [Txn] = []
        
        for legacyTransaction in userData.transactions {
            // Create transaction with sync infrastructure
            let transaction = Txn(
                txID: legacyTransaction.txID,
                accountID: userId,
                walletID: legacyTransaction.walletID,
                category: legacyTransaction.category,
                categoryId: legacyTransaction.categoryId,
                amount: legacyTransaction.amount,
                date: legacyTransaction.date,
                createdAt: legacyTransaction.createdAt,
                receiptImage: legacyTransaction.receiptImage,
                hasReceiptImage: legacyTransaction.hasReceiptImage,
                merchantName: legacyTransaction.merchantName,
                paymentMethod: legacyTransaction.paymentMethod,
                receiptNumber: legacyTransaction.receiptNumber,
                invoiceNumber: legacyTransaction.invoiceNumber,
                items: legacyTransaction.items,
                note: legacyTransaction.note,
                originalAmount: legacyTransaction.originalAmount,
                originalCurrency: legacyTransaction.originalCurrency,
                primaryCurrency: legacyTransaction.primaryCurrency,
                secondaryCurrency: legacyTransaction.secondaryCurrency,
                exchangeRate: legacyTransaction.exchangeRate,
                secondaryAmount: legacyTransaction.secondaryAmount,
                secondaryExchangeRate: legacyTransaction.secondaryExchangeRate,
                // Privacy-first: all transactions start as local-only
                syncMetadata: SyncMetadata.create(),
                syncStatus: .localOnly,
                isLocalOnly: true,
                syncPriority: .high
            )
            
            migratedTransactions.append(transaction)
        }
        
        let financialData = LocalFinancialData(
            userId: userId,
            transactions: migratedTransactions,
            accounts: userData.accounts, // Accounts will need sync infrastructure later
            budgets: [], // Future feature
            createdAt: userData.createdAt,
            updatedAt: Date(),
            backupEnabled: false // Privacy-first default
        )
        
        print("💰 Migrated \(migratedTransactions.count) transactions and \(userData.accounts.count) accounts")
        return financialData
    }
    
    private func saveNewDataStructures(profile: UserProfile, financial: LocalFinancialData) throws {
        // Save using PrivacyDataManager pattern
        let profileData = try JSONEncoder().encode(profile)
        let financialData = try JSONEncoder().encode(financial)
        
        let profileKey = "UserProfile_\(profile.id.uuidString)"
        let financialKey = "LocalFinancialData_\(profile.id.uuidString)"
        
        UserDefaults.standard.set(profileData, forKey: profileKey)
        UserDefaults.standard.set(financialData, forKey: financialKey)
        
        print("💾 Saved new data structures")
    }
    
    private func validateMigration(profile: UserProfile, financial: LocalFinancialData, original: UserData) throws {
        // Validate data integrity after migration
        if profile.name != original.name || profile.email != original.email {
            throw MigrationError.validationFailed("Profile data mismatch")
        }
        
        if financial.transactions.count != original.transactions.count {
            throw MigrationError.validationFailed("Transaction count mismatch")
        }
        
        if financial.accounts.count != original.accounts.count {
            throw MigrationError.validationFailed("Account count mismatch")
        }
        
        // Validate transaction amounts match
        let originalTotal = original.transactions.reduce(0) { $0 + $1.amount }
        let migratedTotal = financial.transactions.reduce(0) { $0 + $1.amount }
        
        if abs(originalTotal - migratedTotal) > 0.01 { // Allow for small rounding differences
            throw MigrationError.validationFailed("Total amount mismatch: \(originalTotal) vs \(migratedTotal)")
        }
        
        print("✅ Migration validation passed")
    }
    
    private func finalizeMigration() {
        // Mark migration as completed
        UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)
        
        // Archive legacy data (don't delete yet for safety)
        if let legacyData = UserDefaults.standard.data(forKey: "UserData") {
            UserDefaults.standard.set(legacyData, forKey: "UserData_Archived")
            print("📦 Legacy data archived")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.migrationStatus = .completed
        }
        
        print("🎉 Migration finalized successfully")
    }
    
    private func performRollback(completion: @escaping (Bool, String?) -> Void) {
        do {
            guard let backupData = UserDefaults.standard.data(forKey: backupStorageKey),
                  let backup = try? JSONDecoder().decode(MigrationBackup.self, from: backupData) else {
                throw MigrationError.rollbackFailed("No backup found")
            }
            
            // Restore legacy data
            UserDefaults.standard.set(backup.legacyUserData, forKey: "UserData")
            
            // Clean up new data structures
            // Note: We should identify and clean these properly
            let profileKeys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix("UserProfile_") }
            let financialKeys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix("LocalFinancialData_") }
            
            for key in profileKeys + financialKeys {
                UserDefaults.standard.removeObject(forKey: key)
            }
            
            // Reset migration state
            UserDefaults.standard.removeObject(forKey: migrationVersionKey)
            
            DispatchQueue.main.async { [weak self] in
                self?.migrationStatus = .rolledBack
                self?.isRollingBack = false
            }
            
            print("⏪ Rollback completed successfully")
            completion(true, nil)
            
        } catch {
            print("❌ Rollback failed: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.isRollingBack = false
            }
            completion(false, error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateProgress(_ progress: Double, step: String) {
        DispatchQueue.main.async { [weak self] in
            self?.migrationProgress = progress
            self?.migrationStep = step
        }
        print("📊 Migration: \(Int(progress * 100))% - \(step)")
    }
    
    private func calculateMigrationTime(transactions: Int, accounts: Int) -> TimeInterval {
        // Estimate based on data complexity
        let baseTime: TimeInterval = 2.0 // Base 2 seconds
        let transactionTime = Double(transactions) * 0.01 // 10ms per transaction
        let accountTime = Double(accounts) * 0.1 // 100ms per account
        
        return baseTime + transactionTime + accountTime
    }
    
    private func estimateDataSize(userData: UserData) -> Int {
        guard let encoded = try? JSONEncoder().encode(userData) else { return 0 }
        return encoded.count
    }
}

// MARK: - Supporting Types

enum MigrationStatus: String, CaseIterable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    case rolledBack = "rolled_back"
    
    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .rolledBack: return "Rolled Back"
        }
    }
}

enum MigrationError: LocalizedError {
    case noLegacyData
    case invalidData(String)
    case backupFailed(String)
    case validationFailed(String)
    case rollbackFailed(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noLegacyData:
            return "No legacy data found to migrate"
        case .invalidData(let details):
            return "Invalid data: \(details)"
        case .backupFailed(let details):
            return "Backup failed: \(details)"
        case .validationFailed(let details):
            return "Validation failed: \(details)"
        case .rollbackFailed(let details):
            return "Rollback failed: \(details)"
        case .unknown(let details):
            return "Unknown error: \(details)"
        }
    }
}

struct MigrationAssessment {
    let canMigrate: Bool
    let reason: String
    let estimatedTime: TimeInterval
    let dataSize: Int
    let transactionCount: Int
    let accountCount: Int
    
    var formattedEstimatedTime: String {
        return String(format: "%.1f seconds", estimatedTime)
    }
    
    var formattedDataSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(dataSize))
    }
}

struct MigrationBackup: Codable {
    let legacyUserData: Data
    let backupDate: Date
    let appVersion: String
    let deviceInfo: DeviceInfo
}