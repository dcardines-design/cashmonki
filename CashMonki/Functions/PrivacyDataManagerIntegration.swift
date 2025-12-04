//
//  PrivacyDataManagerIntegration.swift
//  CashMonki
//
//  Created by Claude on 1/27/25.
//

import Foundation
import SwiftUI

/// Integration layer between legacy UserManager and new PrivacyDataManager
/// Enables seamless transition to privacy-first architecture with "big bang" migration capability
/// Maintains backward compatibility while preparing for enhanced privacy features
class PrivacyDataManagerIntegration: ObservableObject {
    static let shared = PrivacyDataManagerIntegration()
    
    // MARK: - Published Properties
    
    @Published var integrationStatus: IntegrationStatus = .notInitialized
    @Published var migrationRecommended: Bool = false
    @Published var currentDataMode: DataMode = .legacy
    @Published var migrationProgress: MigrationProgress?
    
    // MARK: - Private Properties
    
    private let privacyDataManager = PrivacyDataManager.shared
    private let dataValidation = DataValidationManager.shared
    private let dataMigration = DataMigrationManager.shared
    
    // Legacy UserManager bridge (would interface with existing UserManager)
    private var userManager: UserManagerProtocol?
    
    private init() {
        print("🔗 PrivacyDataManagerIntegration: Initializing integration layer...")
        assessCurrentDataState()
    }
    
    // MARK: - Public Interface
    
    /// Initialize integration with existing UserManager
    func initialize(with userManager: UserManagerProtocol) {
        self.userManager = userManager
        print("🔗 Integration initialized with UserManager")
        
        // Assess migration readiness
        assessMigrationReadiness()
    }
    
    /// Get current user data regardless of architecture mode
    func getCurrentUserData() -> UnifiedUserData? {
        switch currentDataMode {
        case .legacy:
            return getLegacyUserData()
        case .privacyFirst:
            return getPrivacyFirstUserData()
        case .migrating:
            return nil // Don't provide data during migration
        }
    }
    
    /// Execute the "big bang" migration to privacy-first architecture
    func executeBigBangMigration(completion: @escaping (MigrationResult) -> Void) {
        guard integrationStatus == .ready else {
            completion(MigrationResult.failed("Integration not ready for migration"))
            return
        }
        
        print("🚀 Executing big bang migration to privacy-first architecture...")
        
        DispatchQueue.main.async { [weak self] in
            self?.currentDataMode = .migrating
            self?.migrationProgress = MigrationProgress(step: "Initializing", progress: 0.0)
        }
        
        // Execute migration through DataMigrationManager
        dataMigration.executeMigration { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.completeMigrationSuccess()
                    completion(MigrationResult.success)
                } else {
                    self?.completeMigrationFailure(error: error)
                    completion(MigrationResult.failed(error ?? "Unknown migration error"))
                }
            }
        }
    }
    
    /// Check if migration is recommended
    func assessMigrationReadiness() {
        guard let userData = getLegacyUserData()?.userData else {
            DispatchQueue.main.async { [weak self] in
                self?.migrationRecommended = false
                self?.integrationStatus = .noLegacyData
            }
            return
        }
        
        // Validate legacy data for migration readiness
        dataValidation.validatePreMigration(legacyData: userData) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .passed(let issues):
                    let hasBlockingIssues = issues.contains { $0.severity == .critical }
                    self?.migrationRecommended = !hasBlockingIssues
                    self?.integrationStatus = hasBlockingIssues ? .validationFailed : .ready
                case .failed:
                    self?.migrationRecommended = false
                    self?.integrationStatus = .validationFailed
                }
            }
        }
    }
    
    /// Force rollback to legacy mode (emergency use)
    func rollbackToLegacy(completion: @escaping (Bool) -> Void) {
        print("⏪ Rolling back to legacy data mode...")
        
        dataMigration.rollbackMigration { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.currentDataMode = .legacy
                    self?.integrationStatus = .ready
                    print("✅ Rollback to legacy mode successful")
                } else {
                    print("❌ Rollback failed: \(error ?? "Unknown error")")
                }
                completion(success)
            }
        }
    }
    
    /// Get migration assessment for UI display
    func getMigrationAssessment() -> MigrationAssessment? {
        return dataMigration.assessMigration()
    }
    
    /// Enable privacy-first features (post-migration)
    func enablePrivacyFeatures(completion: @escaping (Bool) -> Void) {
        guard currentDataMode == .privacyFirst else {
            completion(false)
            return
        }
        
        // Enable enhanced privacy features
        privacyDataManager.updateUserProfile(enableCloudBackup: false) // Privacy-first default
        
        // Configure financial data for maximum privacy
        if getPrivacyFirstUserData()?.localFinancialData != nil {
            // Update privacy settings through PrivacyDataManager
            print("🔒 Enhanced privacy features enabled")
            completion(true)
        } else {
            completion(false)
        }
    }
    
    // MARK: - Data Access Abstraction
    
    /// Add transaction through appropriate manager
    func addTransaction(_ transaction: Txn, completion: @escaping (Bool) -> Void) {
        switch currentDataMode {
        case .legacy:
            // Add through legacy UserManager
            userManager?.addTransaction(transaction, completion: completion)
        case .privacyFirst:
            // Add through PrivacyDataManager
            privacyDataManager.addTransaction(transaction)
            completion(true)
        case .migrating:
            // Don't allow modifications during migration
            completion(false)
        }
    }
    
    /// Update transaction through appropriate manager
    func updateTransaction(_ transaction: Txn, completion: @escaping (Bool) -> Void) {
        switch currentDataMode {
        case .legacy:
            userManager?.updateTransaction(transaction, completion: completion)
        case .privacyFirst:
            privacyDataManager.updateTransaction(transaction)
            completion(true)
        case .migrating:
            completion(false)
        }
    }
    
    /// Remove transaction through appropriate manager
    func removeTransaction(withId id: UUID, completion: @escaping (Bool) -> Void) {
        switch currentDataMode {
        case .legacy:
            userManager?.removeTransaction(withId: id, completion: completion)
        case .privacyFirst:
            privacyDataManager.removeTransaction(withId: id)
            completion(true)
        case .migrating:
            completion(false)
        }
    }
    
    /// Get total balance through appropriate manager
    var totalBalance: Double {
        switch currentDataMode {
        case .legacy:
            return getLegacyUserData()?.userData?.userBalance ?? 0.0
        case .privacyFirst:
            return privacyDataManager.totalBalance
        case .migrating:
            return 0.0
        }
    }
    
    /// Get transactions through appropriate manager
    var transactions: [Txn] {
        switch currentDataMode {
        case .legacy:
            return getLegacyUserData()?.userData?.transactions ?? []
        case .privacyFirst:
            return privacyDataManager.transactions
        case .migrating:
            return []
        }
    }
    
    /// Get accounts through appropriate manager
    var accounts: [AccountData] {
        switch currentDataMode {
        case .legacy:
            return getLegacyUserData()?.userData?.accounts ?? []
        case .privacyFirst:
            return privacyDataManager.accounts
        case .migrating:
            return []
        }
    }
    
    // MARK: - Private Implementation
    
    private func assessCurrentDataState() {
        // Check if privacy-first data exists
        let hasPrivacyFirstData = checkForPrivacyFirstData()
        let hasLegacyData = checkForLegacyData()
        
        if hasPrivacyFirstData {
            currentDataMode = .privacyFirst
            integrationStatus = .migrationCompleted
        } else if hasLegacyData {
            currentDataMode = .legacy
            integrationStatus = .pendingMigration
        } else {
            currentDataMode = .legacy
            integrationStatus = .noData
        }
        
        print("🔍 Current data mode: \(currentDataMode.displayName)")
        print("🔍 Integration status: \(integrationStatus.displayName)")
    }
    
    private func checkForPrivacyFirstData() -> Bool {
        // Check if UserProfile and LocalFinancialData exist
        // This would check UserDefaults or other storage for migrated data
        return UserDefaults.standard.data(forKey: "UserProfile") != nil
    }
    
    private func checkForLegacyData() -> Bool {
        // Check if legacy UserData exists
        return UserDefaults.standard.data(forKey: "UserData") != nil
    }
    
    private func getLegacyUserData() -> UnifiedUserData? {
        guard let data = UserDefaults.standard.data(forKey: "UserData"),
              let userData = try? JSONDecoder().decode(UserData.self, from: data) else {
            return nil
        }
        
        return UnifiedUserData(mode: .legacy, userData: userData)
    }
    
    private func getPrivacyFirstUserData() -> UnifiedUserData? {
        guard let profile = privacyDataManager.userProfile,
              let financial = privacyDataManager.financialData else {
            return nil
        }
        
        return UnifiedUserData(mode: .privacyFirst, userProfile: profile, localFinancialData: financial)
    }
    
    private func completeMigrationSuccess() {
        currentDataMode = .privacyFirst
        integrationStatus = .migrationCompleted
        migrationProgress = nil
        migrationRecommended = false
        
        print("🎉 Big bang migration completed successfully!")
        
        // Archive legacy data for safety
        if let legacyData = UserDefaults.standard.data(forKey: "UserData") {
            UserDefaults.standard.set(legacyData, forKey: "UserData_PreMigration_\(Date().timeIntervalSince1970)")
            print("📦 Legacy data archived for safety")
        }
    }
    
    private func completeMigrationFailure(error: String?) {
        currentDataMode = .legacy
        integrationStatus = .migrationFailed
        migrationProgress = nil
        
        print("❌ Big bang migration failed: \(error ?? "Unknown error")")
    }
}

// MARK: - Supporting Types

/// Current data architecture mode
enum DataMode: String, CaseIterable {
    case legacy = "legacy"
    case privacyFirst = "privacy_first"
    case migrating = "migrating"
    
    var displayName: String {
        switch self {
        case .legacy: return "Legacy Architecture"
        case .privacyFirst: return "Privacy-First Architecture"
        case .migrating: return "Migrating"
        }
    }
    
    var isReadyForOperations: Bool {
        switch self {
        case .legacy, .privacyFirst: return true
        case .migrating: return false
        }
    }
}

/// Integration status between managers
enum IntegrationStatus: String, CaseIterable {
    case notInitialized = "not_initialized"
    case noData = "no_data"
    case noLegacyData = "no_legacy_data"
    case pendingMigration = "pending_migration"
    case ready = "ready"
    case validationFailed = "validation_failed"
    case migrating = "migrating"
    case migrationCompleted = "migration_completed"
    case migrationFailed = "migration_failed"
    
    var displayName: String {
        switch self {
        case .notInitialized: return "Not Initialized"
        case .noData: return "No Data"
        case .noLegacyData: return "No Legacy Data"
        case .pendingMigration: return "Pending Migration"
        case .ready: return "Ready"
        case .validationFailed: return "Validation Failed"
        case .migrating: return "Migrating"
        case .migrationCompleted: return "Migration Completed"
        case .migrationFailed: return "Migration Failed"
        }
    }
}

/// Migration progress tracking
struct MigrationProgress {
    let step: String
    let progress: Double // 0.0 to 1.0
    let timestamp: Date
    
    init(step: String, progress: Double) {
        self.step = step
        self.progress = max(0.0, min(1.0, progress))
        self.timestamp = Date()
    }
    
    var formattedProgress: String {
        return String(format: "%.0f%%", progress * 100)
    }
}

/// Migration execution result
enum MigrationResult {
    case success
    case failed(String)
    
    var isSuccessful: Bool {
        switch self {
        case .success: return true
        case .failed: return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .success: return nil
        case .failed(let message): return message
        }
    }
}

/// Unified data container for both architectures
struct UnifiedUserData {
    let mode: DataMode
    let userData: UserData? // Legacy architecture
    let userProfile: UserProfile? // Privacy-first architecture
    let localFinancialData: LocalFinancialData? // Privacy-first architecture
    
    init(mode: DataMode, userData: UserData? = nil, userProfile: UserProfile? = nil, localFinancialData: LocalFinancialData? = nil) {
        self.mode = mode
        self.userData = userData
        self.userProfile = userProfile
        self.localFinancialData = localFinancialData
    }
    
    /// Get user name regardless of architecture
    var userName: String {
        switch mode {
        case .legacy:
            return userData?.name ?? ""
        case .privacyFirst, .migrating:
            return userProfile?.name ?? ""
        }
    }
    
    /// Get user email regardless of architecture
    var userEmail: String {
        switch mode {
        case .legacy:
            return userData?.email ?? ""
        case .privacyFirst, .migrating:
            return userProfile?.email ?? ""
        }
    }
    
    /// Get total balance regardless of architecture
    var totalBalance: Double {
        switch mode {
        case .legacy:
            return userData?.userBalance ?? 0.0
        case .privacyFirst, .migrating:
            return localFinancialData?.totalBalance ?? 0.0
        }
    }
    
    /// Get transaction count regardless of architecture
    var transactionCount: Int {
        switch mode {
        case .legacy:
            return userData?.transactions.count ?? 0
        case .privacyFirst, .migrating:
            return localFinancialData?.transactions.count ?? 0
        }
    }
    
    /// Get account count regardless of architecture
    var accountCount: Int {
        switch mode {
        case .legacy:
            return userData?.accounts.count ?? 0
        case .privacyFirst, .migrating:
            return localFinancialData?.accounts.count ?? 0
        }
    }
}

/// Protocol for legacy UserManager integration
protocol UserManagerProtocol {
    func addTransaction(_ transaction: Txn, completion: @escaping (Bool) -> Void)
    func updateTransaction(_ transaction: Txn, completion: @escaping (Bool) -> Void)
    func removeTransaction(withId id: UUID, completion: @escaping (Bool) -> Void)
    func getCurrentUserData() -> UserData?
}

// MARK: - Convenience Extensions

extension PrivacyDataManagerIntegration {
    
    /// Check if app should show migration UI
    var shouldShowMigrationUI: Bool {
        return migrationRecommended && integrationStatus == .ready
    }
    
    /// Check if app is ready for normal operations
    var isReadyForOperations: Bool {
        return currentDataMode.isReadyForOperations && integrationStatus != .validationFailed
    }
    
    /// Get current architecture description for UI
    var currentArchitectureDescription: String {
        switch currentDataMode {
        case .legacy:
            return "Using legacy data architecture. Migration to privacy-first architecture recommended."
        case .privacyFirst:
            return "Using privacy-first data architecture with enhanced security and future sync capabilities."
        case .migrating:
            return "Migration in progress. Please wait for completion."
        }
    }
    
    /// Get privacy benefits description
    var privacyBenefitsDescription: [String] {
        return [
            "🔒 Financial data stays on your device by default",
            "🛡️ Enhanced encryption and access controls",
            "📱 Ready for future multi-device sync (when you choose)",
            "🔍 Comprehensive audit logs for data access",
            "⚙️ Granular privacy and sync preferences"
        ]
    }
}

// MARK: - SwiftUI Helpers

extension PrivacyDataManagerIntegration {
    
    /// Get integration status color for UI
    var integrationStatusColor: Color {
        switch integrationStatus {
        case .notInitialized, .noData:
            return .gray
        case .noLegacyData, .ready, .migrationCompleted:
            return .green
        case .pendingMigration:
            return .orange
        case .validationFailed, .migrationFailed:
            return .red
        case .migrating:
            return .blue
        }
    }
    
    /// Get data mode color for UI
    var dataModeColor: Color {
        switch currentDataMode {
        case .legacy:
            return .orange
        case .privacyFirst:
            return .green
        case .migrating:
            return .blue
        }
    }
}