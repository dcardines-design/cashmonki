import Foundation
import SwiftUI

// MARK: - Privacy-First Data Models

/// User profile data that can be safely stored in cloud
/// Contains only non-sensitive identity and preference data
/// Optimized for cloud storage with sync infrastructure
struct UserProfile: Identifiable, Codable {
    let id: UUID
    let firebaseUID: String // For Firebase operations
    var name: String
    var email: String
    let createdAt: Date
    var updatedAt: Date
    
    // App preferences (non-financial)
    var preferredCurrency: Currency
    var enableCloudBackup: Bool // Whether user wants optional financial data backup
    var subscriptionTier: SubscriptionTier
    var languageCode: String
    var notificationSettings: NotificationSettings
    
    // MARK: - Enhanced Cloud Storage Features
    
    // Cloud sync preferences
    var cloudSyncSettings: CloudSyncSettings
    var privacySettings: PrivacySettings
    var devicePreferences: DevicePreferences
    
    // Account management
    var profileImageURL: String? // Cloud-stored profile image
    var isEmailVerified: Bool
    var phoneNumber: String?
    var timezone: String // User's timezone for accurate data display
    var lastActiveAt: Date // Track user activity for stale account cleanup
    
    // Multi-device management (future-ready)
    var registeredDevices: [UUID] // Device IDs that can access this profile
    var primaryDeviceId: UUID? // Primary device for conflict resolution
    var maxDeviceLimit: Int // Based on subscription tier
    
    // Cloud-specific metadata
    var cloudStorageUsage: CloudStorageUsage
    var dataRetentionSettings: DataRetentionSettings
    var syncMetadata: SyncMetadata // Profile sync state
    
    init(
        id: UUID = UUID(),
        firebaseUID: String,
        name: String,
        email: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        preferredCurrency: Currency = .php,
        enableCloudBackup: Bool = false, // Default to private (local-only)
        subscriptionTier: SubscriptionTier = .free,
        languageCode: String = "en",
        notificationSettings: NotificationSettings = NotificationSettings(),
        // Enhanced cloud storage parameters
        cloudSyncSettings: CloudSyncSettings = CloudSyncSettings(),
        privacySettings: PrivacySettings = PrivacySettings(),
        devicePreferences: DevicePreferences = DevicePreferences(),
        profileImageURL: String? = nil,
        isEmailVerified: Bool = false,
        phoneNumber: String? = nil,
        timezone: String = TimeZone.current.identifier,
        lastActiveAt: Date = Date(),
        registeredDevices: [UUID] = [],
        primaryDeviceId: UUID? = nil,
        maxDeviceLimit: Int? = nil,
        cloudStorageUsage: CloudStorageUsage = CloudStorageUsage(),
        dataRetentionSettings: DataRetentionSettings = DataRetentionSettings(),
        syncMetadata: SyncMetadata? = nil
    ) {
        self.id = id
        self.firebaseUID = firebaseUID
        self.name = name
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.preferredCurrency = preferredCurrency
        self.enableCloudBackup = enableCloudBackup
        self.subscriptionTier = subscriptionTier
        self.languageCode = languageCode
        self.notificationSettings = notificationSettings
        
        // Enhanced cloud features
        self.cloudSyncSettings = cloudSyncSettings
        self.privacySettings = privacySettings
        self.devicePreferences = devicePreferences
        self.profileImageURL = profileImageURL
        self.isEmailVerified = isEmailVerified
        self.phoneNumber = phoneNumber
        self.timezone = timezone
        self.lastActiveAt = lastActiveAt
        self.registeredDevices = registeredDevices
        self.primaryDeviceId = primaryDeviceId
        self.maxDeviceLimit = maxDeviceLimit ?? subscriptionTier.defaultDeviceLimit
        self.cloudStorageUsage = cloudStorageUsage
        self.dataRetentionSettings = dataRetentionSettings
        self.syncMetadata = syncMetadata ?? SyncMetadata.create()
    }
    
    // MARK: - Cloud-Ready Computed Properties
    
    /// Check if user can enable multi-device sync
    var canEnableMultiDeviceSync: Bool {
        return subscriptionTier.supportsMultiDevice && isEmailVerified
    }
    
    /// Check if user has reached device limit
    var hasReachedDeviceLimit: Bool {
        return registeredDevices.count >= maxDeviceLimit
    }
    
    /// Get cloud storage quota based on subscription
    var cloudStorageQuota: Int {
        return subscriptionTier.cloudStorageQuota
    }
    
    /// Check if profile data should be synced to cloud
    var shouldSyncToCloud: Bool {
        return cloudSyncSettings.enableProfileSync && isEmailVerified
    }
    
    /// Check if user is inactive and should be flagged for cleanup
    var isInactiveUser: Bool {
        return Date().timeIntervalSince(lastActiveAt) > dataRetentionSettings.inactivityThreshold
    }
    
    // MARK: - Cloud Management Methods
    
    /// Register a new device with this profile
    mutating func registerDevice(_ deviceId: UUID) -> Bool {
        guard !hasReachedDeviceLimit else { return false }
        guard !registeredDevices.contains(deviceId) else { return true }
        
        registeredDevices.append(deviceId)
        
        // Set as primary device if it's the first one
        if primaryDeviceId == nil {
            primaryDeviceId = deviceId
        }
        
        markAsModified()
        return true
    }
    
    /// Remove a device from this profile
    mutating func removeDevice(_ deviceId: UUID) {
        registeredDevices.removeAll { $0 == deviceId }
        
        // Update primary device if removed
        if primaryDeviceId == deviceId {
            primaryDeviceId = registeredDevices.first
        }
        
        markAsModified()
    }
    
    /// Update cloud storage usage
    mutating func updateCloudStorageUsage(_ usage: CloudStorageUsage) {
        cloudStorageUsage = usage
        markAsModified()
    }
    
    /// Mark profile as modified for sync
    mutating func markAsModified() {
        updatedAt = Date()
        lastActiveAt = Date()
        syncMetadata.markModified()
    }
    
    /// Verify email address
    mutating func verifyEmail() {
        isEmailVerified = true
        markAsModified()
    }
    
    /// Update privacy settings
    mutating func updatePrivacySettings(_ settings: PrivacySettings) {
        privacySettings = settings
        markAsModified()
    }
    
    /// Update cloud sync settings
    mutating func updateCloudSyncSettings(_ settings: CloudSyncSettings) {
        cloudSyncSettings = settings
        markAsModified()
    }
}

// MARK: - Enhanced Cloud Storage Support Models

/// Cloud synchronization preferences for user profiles
struct CloudSyncSettings: Codable {
    var enableProfileSync: Bool // Sync profile data across devices
    var enableSettingsSync: Bool // Sync app preferences across devices
    var enableCategoriesSync: Bool // Sync custom categories across devices
    var autoSyncInterval: TimeInterval // How often to sync in background
    var syncOnlyWiFi: Bool // Restrict sync to WiFi connections
    var enableConflictResolution: Bool // Auto-resolve sync conflicts
    var lowPowerModeDisableSync: Bool // Disable sync in low power mode
    
    init(
        enableProfileSync: Bool = true, // Safe to sync non-financial data
        enableSettingsSync: Bool = true,
        enableCategoriesSync: Bool = true,
        autoSyncInterval: TimeInterval = 300, // 5 minutes
        syncOnlyWiFi: Bool = false,
        enableConflictResolution: Bool = true,
        lowPowerModeDisableSync: Bool = true
    ) {
        self.enableProfileSync = enableProfileSync
        self.enableSettingsSync = enableSettingsSync
        self.enableCategoriesSync = enableCategoriesSync
        self.autoSyncInterval = autoSyncInterval
        self.syncOnlyWiFi = syncOnlyWiFi
        self.enableConflictResolution = enableConflictResolution
        self.lowPowerModeDisableSync = lowPowerModeDisableSync
    }
}

/// Privacy controls for cloud data and sharing
struct PrivacySettings: Codable {
    var allowAnalytics: Bool // Allow anonymous usage analytics
    var allowCrashReporting: Bool // Allow crash data collection
    var shareUsageData: Bool // Share non-financial usage patterns
    var allowProfileInSearch: Bool // Allow profile discovery by email
    var enableDataExport: Bool // Allow data export requests
    var autoDeleteAfterInactivity: Bool // Auto-delete after long inactivity
    var requireBiometricForBackup: Bool // Require biometric auth for cloud backup
    
    init(
        allowAnalytics: Bool = false, // Privacy-first defaults
        allowCrashReporting: Bool = true, // Helpful for app stability
        shareUsageData: Bool = false,
        allowProfileInSearch: Bool = false,
        enableDataExport: Bool = true, // User rights
        autoDeleteAfterInactivity: Bool = false,
        requireBiometricForBackup: Bool = true
    ) {
        self.allowAnalytics = allowAnalytics
        self.allowCrashReporting = allowCrashReporting
        self.shareUsageData = shareUsageData
        self.allowProfileInSearch = allowProfileInSearch
        self.enableDataExport = enableDataExport
        self.autoDeleteAfterInactivity = autoDeleteAfterInactivity
        self.requireBiometricForBackup = requireBiometricForBackup
    }
}

/// Device-specific preferences that sync with profile
struct DevicePreferences: Codable {
    var preferredTheme: AppTheme // Light/Dark/Auto
    var preferredLayout: LayoutStyle // Compact/Comfortable/Spacious
    var enableHapticFeedback: Bool
    var preferredChartStyle: ChartStyle // Bar/Line/Pie preferences
    var defaultTransactionView: TransactionViewStyle // List/Grid/Timeline
    var enableQuickActions: Bool // Shortcuts and gestures
    
    init(
        preferredTheme: AppTheme = .system,
        preferredLayout: LayoutStyle = .comfortable,
        enableHapticFeedback: Bool = true,
        preferredChartStyle: ChartStyle = .auto,
        defaultTransactionView: TransactionViewStyle = .list,
        enableQuickActions: Bool = true
    ) {
        self.preferredTheme = preferredTheme
        self.preferredLayout = preferredLayout
        self.enableHapticFeedback = enableHapticFeedback
        self.preferredChartStyle = preferredChartStyle
        self.defaultTransactionView = defaultTransactionView
        self.enableQuickActions = enableQuickActions
    }
}

/// Cloud storage usage tracking
struct CloudStorageUsage: Codable {
    var profileDataSize: Int // Profile and settings size in bytes
    var backupDataSize: Int // Financial backup size in bytes
    var imageDataSize: Int // Receipt images size in bytes
    var totalUsedBytes: Int // Total cloud storage used
    var lastUpdated: Date // When usage was last calculated
    
    init(
        profileDataSize: Int = 0,
        backupDataSize: Int = 0,
        imageDataSize: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.profileDataSize = profileDataSize
        self.backupDataSize = backupDataSize
        self.imageDataSize = imageDataSize
        self.totalUsedBytes = profileDataSize + backupDataSize + imageDataSize
        self.lastUpdated = lastUpdated
    }
    
    var usagePercentage: Double {
        // This would need access to quota from subscription tier
        return 0.0 // Calculated elsewhere
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalUsedBytes))
    }
}

/// Data retention and cleanup settings
struct DataRetentionSettings: Codable {
    var inactivityThreshold: TimeInterval // Consider user inactive after this period
    var autoBackupFrequency: BackupFrequency
    var keepBackupVersions: Int // Number of backup versions to retain
    var autoDeleteOldBackups: Bool
    var exportReminderInterval: TimeInterval // Remind user to export data
    
    init(
        inactivityThreshold: TimeInterval = 365 * 24 * 60 * 60, // 1 year
        autoBackupFrequency: BackupFrequency = .weekly,
        keepBackupVersions: Int = 5,
        autoDeleteOldBackups: Bool = true,
        exportReminderInterval: TimeInterval = 90 * 24 * 60 * 60 // 90 days
    ) {
        self.inactivityThreshold = inactivityThreshold
        self.autoBackupFrequency = autoBackupFrequency
        self.keepBackupVersions = keepBackupVersions
        self.autoDeleteOldBackups = autoDeleteOldBackups
        self.exportReminderInterval = exportReminderInterval
    }
}

// MARK: - Supporting Enums for Cloud Features

enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum LayoutStyle: String, Codable, CaseIterable {
    case compact = "compact"
    case comfortable = "comfortable"
    case spacious = "spacious"
    
    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .comfortable: return "Comfortable"
        case .spacious: return "Spacious"
        }
    }
}

enum ChartStyle: String, Codable, CaseIterable {
    case bar = "bar"
    case line = "line"
    case pie = "pie"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .bar: return "Bar Charts"
        case .line: return "Line Charts"
        case .pie: return "Pie Charts"
        case .auto: return "Automatic"
        }
    }
}

enum TransactionViewStyle: String, Codable, CaseIterable {
    case list = "list"
    case grid = "grid"
    case timeline = "timeline"
    
    var displayName: String {
        switch self {
        case .list: return "List View"
        case .grid: return "Grid View"
        case .timeline: return "Timeline View"
        }
    }
}

enum BackupFrequency: String, Codable, CaseIterable {
    case never = "never"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .never: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
    
    var intervalSeconds: TimeInterval? {
        switch self {
        case .never: return nil
        case .daily: return 24 * 60 * 60
        case .weekly: return 7 * 24 * 60 * 60
        case .monthly: return 30 * 24 * 60 * 60
        }
    }
}

/// Local financial data that stays on device for privacy
/// Contains all sensitive financial information with sync infrastructure (dormant)
struct LocalFinancialData: Codable {
    let userId: UUID // Links to UserProfile
    var transactions: [Txn]
    var accounts: [AccountData]
    var budgets: [BudgetData] // Future feature
    let createdAt: Date
    var updatedAt: Date
    
    // MARK: - Enhanced Privacy-First Sync Infrastructure
    
    // Optional cloud backup metadata (when user explicitly enables backup)
    var lastBackupDate: Date?
    var backupEnabled: Bool
    var encryptedBackupEnabled: Bool // Whether to use client-side encryption for backups
    var backupFrequency: BackupFrequency
    var autoBackupSettings: AutoBackupSettings
    
    // Data integrity and sync infrastructure (dormant until activated)
    var dataIntegrity: DataIntegrityInfo
    var syncSettings: FinancialDataSyncSettings
    var conflictResolution: FinancialDataConflictSettings
    
    // Local data management
    var dataVersion: String // For migration and compatibility tracking
    var lastLocalSave: Date
    var compressionEnabled: Bool // Compress local data to save space
    var localEncryptionEnabled: Bool // Encrypt sensitive data at rest
    
    // Privacy protection
    var dataClassification: DataClassification
    var accessControl: AccessControlSettings
    var auditLog: [DataAccessLogEntry] // Track who/what accessed this data
    
    init(
        userId: UUID,
        transactions: [Txn] = [],
        accounts: [AccountData] = [],
        budgets: [BudgetData] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backupEnabled: Bool = false,
        // Enhanced privacy-first parameters
        encryptedBackupEnabled: Bool = true, // Always encrypt backups by default
        backupFrequency: BackupFrequency = .never, // Privacy-first: no auto backup
        autoBackupSettings: AutoBackupSettings = AutoBackupSettings(),
        dataIntegrity: DataIntegrityInfo = DataIntegrityInfo(),
        syncSettings: FinancialDataSyncSettings = FinancialDataSyncSettings(),
        conflictResolution: FinancialDataConflictSettings = FinancialDataConflictSettings(),
        dataVersion: String = "1.0.0",
        compressionEnabled: Bool = true,
        localEncryptionEnabled: Bool = true, // Always encrypt locally by default
        dataClassification: DataClassification = .highlyConfidential,
        accessControl: AccessControlSettings = AccessControlSettings()
    ) {
        self.userId = userId
        self.transactions = transactions
        self.accounts = accounts
        self.budgets = budgets
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backupEnabled = backupEnabled
        
        // Enhanced privacy-first features
        self.encryptedBackupEnabled = encryptedBackupEnabled
        self.backupFrequency = backupFrequency
        self.autoBackupSettings = autoBackupSettings
        self.dataIntegrity = dataIntegrity
        self.syncSettings = syncSettings
        self.conflictResolution = conflictResolution
        self.dataVersion = dataVersion
        self.lastLocalSave = Date()
        self.compressionEnabled = compressionEnabled
        self.localEncryptionEnabled = localEncryptionEnabled
        self.dataClassification = dataClassification
        self.accessControl = accessControl
        self.auditLog = []
    }
    
    
    // MARK: - Enhanced Computed Properties
    
    var totalBalance: Double {
        return transactions.reduce(0) { $0 + $1.amount }
    }
    
    func balance(for walletId: UUID) -> Double {
        return transactions.filter { $0.walletID == walletId }.reduce(0) { $0 + $1.amount }
    }
    
    func transactions(for walletId: UUID) -> [Txn] {
        return transactions.filter { $0.walletID == walletId }
    }
    
    /// Check if financial data needs backup based on settings
    var needsBackup: Bool {
        guard backupEnabled else { return false }
        guard let lastBackup = lastBackupDate else { return true }
        guard let interval = backupFrequency.intervalSeconds else { return false }
        
        return Date().timeIntervalSince(lastBackup) > interval
    }
    
    /// Check if local data has sync conflicts
    var hasSyncConflicts: Bool {
        return transactions.contains { $0.hasConflicts }
    }
    
    /// Count of transactions pending sync (when sync is enabled)
    var pendingSyncCount: Int {
        return transactions.filter { $0.needsSync }.count
    }
    
    /// Data integrity status
    var integrityStatus: DataIntegrityStatus {
        return dataIntegrity.currentStatus
    }
    
    /// Total local storage size estimate
    var estimatedLocalSize: Int {
        // Rough estimation - could be more precise with actual measurement
        let transactionSize = transactions.count * 500 // ~500 bytes per transaction
        let accountSize = accounts.count * 200 // ~200 bytes per account
        let auditLogSize = auditLog.count * 150 // ~150 bytes per audit entry
        
        return transactionSize + accountSize + auditLogSize
    }
    
    /// Check if data should be compressed
    var shouldCompress: Bool {
        return compressionEnabled && estimatedLocalSize > 50_000 // 50KB threshold
    }
    
    // MARK: - Enhanced Data Modification Methods
    
    mutating func addTransaction(_ transaction: Txn) {
        transactions.append(transaction)
        markAsModified(action: "add_transaction", details: "Added transaction: \(transaction.id)")
        updateDataIntegrity()
    }
    
    mutating func removeTransaction(withId id: UUID) {
        let removedCount = transactions.count
        transactions.removeAll { $0.id == id }
        
        if transactions.count < removedCount {
            markAsModified(action: "remove_transaction", details: "Removed transaction: \(id)")
            updateDataIntegrity()
        }
    }
    
    mutating func updateTransaction(_ updatedTransaction: Txn) {
        if let index = transactions.firstIndex(where: { $0.id == updatedTransaction.id }) {
            transactions[index] = updatedTransaction
            markAsModified(action: "update_transaction", details: "Updated transaction: \(updatedTransaction.id)")
            updateDataIntegrity()
        }
    }
    
    mutating func addAccount(_ account: AccountData) {
        accounts.append(account)
        markAsModified(action: "add_account", details: "Added account: \(account.name)")
        updateDataIntegrity()
    }
    
    mutating func removeAccount(withId accountId: UUID, reassignToAccountId: UUID? = nil) {
        let accountName = accounts.first { $0.id == accountId }?.name ?? "Unknown"
        accounts.removeAll { $0.id == accountId }
        
        // Reassign transactions to another wallet or set to nil
        let affectedTransactions = transactions.filter { $0.walletID == accountId }.count
        for index in transactions.indices {
            if transactions[index].walletID == accountId {
                var transaction = transactions[index]
                transaction = Txn(
                    txID: transaction.txID,
                    accountID: transaction.accountID,
                    walletID: reassignToAccountId,
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
                transactions[index] = transaction
            }
        }
        
        markAsModified(action: "remove_account", details: "Removed account: \(accountName), reassigned \(affectedTransactions) transactions")
        updateDataIntegrity()
    }
    
    // MARK: - Privacy-First Data Management
    
    /// Mark data as modified with audit trail
    private mutating func markAsModified(action: String, details: String) {
        updatedAt = Date()
        lastLocalSave = Date()
        
        // Add audit log entry
        let logEntry = DataAccessLogEntry(
            timestamp: Date(),
            action: action,
            details: details,
            userId: userId,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )
        auditLog.append(logEntry)
        
        // Limit audit log size
        if auditLog.count > 1000 {
            auditLog.removeFirst(auditLog.count - 1000)
        }
        
        // Update data integrity
        updateDataIntegrity()
    }
    
    /// Update data integrity information
    private mutating func updateDataIntegrity() {
        dataIntegrity.lastValidated = Date()
        dataIntegrity.transactionCount = transactions.count
        dataIntegrity.accountCount = accounts.count
        dataIntegrity.dataHash = calculateDataHash()
        dataIntegrity.currentStatus = .valid // Could add more sophisticated validation
    }
    
    /// Calculate data hash for integrity checking
    private func calculateDataHash() -> String {
        // Simple hash of critical data for integrity checking
        let criticalData = "\(userId)\(transactions.count)\(accounts.count)\(totalBalance)"
        return String(criticalData.hashValue)
    }
    
    /// Enable encrypted backup for financial data
    mutating func enableEncryptedBackup(frequency: BackupFrequency = .weekly) {
        backupEnabled = true
        encryptedBackupEnabled = true
        backupFrequency = frequency
        markAsModified(action: "enable_backup", details: "Enabled encrypted backup with frequency: \(frequency.displayName)")
    }
    
    /// Disable all backup functionality
    mutating func disableBackup() {
        backupEnabled = false
        encryptedBackupEnabled = false
        backupFrequency = .never
        lastBackupDate = nil
        markAsModified(action: "disable_backup", details: "Disabled all backup functionality")
    }
    
    /// Update sync settings (for future multi-device support)
    mutating func updateSyncSettings(_ settings: FinancialDataSyncSettings) {
        syncSettings = settings
        markAsModified(action: "update_sync_settings", details: "Updated sync settings")
    }
    
    /// Mark backup as completed
    mutating func markBackupCompleted() {
        lastBackupDate = Date()
        markAsModified(action: "backup_completed", details: "Backup completed successfully")
    }
    
    /// Get transactions that need sync (when sync is enabled in future)
    func transactionsNeedingSync() -> [Txn] {
        return transactions.filter { $0.needsSync }
    }
    
    /// Get data classification level
    var classificationLevel: String {
        return dataClassification.displayName
    }
    
    /// Check if data access is allowed based on current security context
    func isAccessAllowed() -> Bool {
        return accessControl.isAccessAllowed()
    }
    
    /// Get recent audit entries
    func recentAuditEntries(limit: Int = 10) -> [DataAccessLogEntry] {
        return Array(auditLog.suffix(limit).reversed())
    }
}

// MARK: - Financial Data Sync Infrastructure Support Models

/// Auto backup settings for financial data
struct AutoBackupSettings: Codable {
    var enableWiFiOnlyBackup: Bool // Only backup on WiFi
    var enableLowPowerModeBackup: Bool // Allow backup in low power mode
    var backupRetentionDays: Int // How long to keep old backups
    var maxBackupSize: Int // Maximum backup size in bytes
    var compressionLevel: CompressionLevel // Backup compression level
    var enableIncrementalBackup: Bool // Only backup changes
    
    init(
        enableWiFiOnlyBackup: Bool = true, // Privacy-first: conservative defaults
        enableLowPowerModeBackup: Bool = false,
        backupRetentionDays: Int = 30,
        maxBackupSize: Int = 100 * 1024 * 1024, // 100MB
        compressionLevel: CompressionLevel = .balanced,
        enableIncrementalBackup: Bool = true
    ) {
        self.enableWiFiOnlyBackup = enableWiFiOnlyBackup
        self.enableLowPowerModeBackup = enableLowPowerModeBackup
        self.backupRetentionDays = backupRetentionDays
        self.maxBackupSize = maxBackupSize
        self.compressionLevel = compressionLevel
        self.enableIncrementalBackup = enableIncrementalBackup
    }
}

/// Data integrity information for financial data
struct DataIntegrityInfo: Codable {
    var lastValidated: Date
    var transactionCount: Int
    var accountCount: Int
    var dataHash: String // Hash for integrity verification
    var currentStatus: DataIntegrityStatus
    var validationHistory: [IntegrityValidation] // Track validation history
    
    init(
        lastValidated: Date = Date(),
        transactionCount: Int = 0,
        accountCount: Int = 0,
        dataHash: String = "",
        currentStatus: DataIntegrityStatus = .unknown,
        validationHistory: [IntegrityValidation] = []
    ) {
        self.lastValidated = lastValidated
        self.transactionCount = transactionCount
        self.accountCount = accountCount
        self.dataHash = dataHash
        self.currentStatus = currentStatus
        self.validationHistory = validationHistory
    }
}

/// Financial data sync settings (dormant until activated)
struct FinancialDataSyncSettings: Codable {
    var enableFinancialDataSync: Bool // Master switch for financial sync
    var syncTransactions: Bool // Sync transaction data
    var syncAccounts: Bool // Sync account data
    var syncCategories: Bool // Sync custom categories
    var conflictResolutionStrategy: ConflictResolutionStrategy
    var encryptionRequired: Bool // Require encryption for sync
    var selectiveSync: Bool // Only sync specific wallets/categories
    var selectedWalletIds: [UUID] // Wallets to sync (if selective sync enabled)
    
    init(
        enableFinancialDataSync: Bool = false, // Privacy-first: disabled by default
        syncTransactions: Bool = false,
        syncAccounts: Bool = false,
        syncCategories: Bool = true, // Categories are less sensitive
        conflictResolutionStrategy: ConflictResolutionStrategy = .manualResolution,
        encryptionRequired: Bool = true, // Always require encryption
        selectiveSync: Bool = true, // Privacy-first: selective by default
        selectedWalletIds: [UUID] = []
    ) {
        self.enableFinancialDataSync = enableFinancialDataSync
        self.syncTransactions = syncTransactions
        self.syncAccounts = syncAccounts
        self.syncCategories = syncCategories
        self.conflictResolutionStrategy = conflictResolutionStrategy
        self.encryptionRequired = encryptionRequired
        self.selectiveSync = selectiveSync
        self.selectedWalletIds = selectedWalletIds
    }
}

/// Conflict resolution settings for financial data
struct FinancialDataConflictSettings: Codable {
    var autoResolveConflicts: Bool
    var preferLocalChanges: Bool // Prefer local changes over cloud
    var enableConflictLogging: Bool // Log all conflicts for review
    var conflictNotifications: Bool // Notify user of conflicts
    var maxConflictRetentionDays: Int // How long to keep conflict records
    
    init(
        autoResolveConflicts: Bool = false, // Privacy-first: require user decision
        preferLocalChanges: Bool = true, // Privacy-first: local data wins
        enableConflictLogging: Bool = true,
        conflictNotifications: Bool = true,
        maxConflictRetentionDays: Int = 90
    ) {
        self.autoResolveConflicts = autoResolveConflicts
        self.preferLocalChanges = preferLocalChanges
        self.enableConflictLogging = enableConflictLogging
        self.conflictNotifications = conflictNotifications
        self.maxConflictRetentionDays = maxConflictRetentionDays
    }
}

/// Data classification levels for financial information
enum DataClassification: String, Codable, CaseIterable {
    case publicData = "public"                     // Non-sensitive data
    case internalData = "internal"                 // Internal app data
    case confidential = "confidential"         // Sensitive but not financial
    case highlyConfidential = "highly_confidential" // Financial data (default)
    case restricted = "restricted"             // Highly restricted financial data
    
    var displayName: String {
        switch self {
        case .publicData: return "Public"
        case .internalData: return "Internal"
        case .confidential: return "Confidential"
        case .highlyConfidential: return "Highly Confidential"
        case .restricted: return "Restricted"
        }
    }
    
    var securityLevel: Int {
        switch self {
        case .publicData: return 1
        case .internalData: return 2
        case .confidential: return 3
        case .highlyConfidential: return 4
        case .restricted: return 5
        }
    }
}

/// Access control settings for financial data
struct AccessControlSettings: Codable {
    var requireBiometric: Bool // Require biometric authentication
    var requirePin: Bool // Require PIN authentication
    var sessionTimeout: TimeInterval // Auto-logout after inactivity
    var allowScreenshots: Bool // Allow screenshots of financial data
    var allowCopy: Bool // Allow copying sensitive data
    var enableAuditLog: Bool // Track all data access
    var restrictedHours: RestrictedHours? // Time-based access restrictions
    
    init(
        requireBiometric: Bool = true, // Privacy-first: secure by default
        requirePin: Bool = false,
        sessionTimeout: TimeInterval = 900, // 15 minutes
        allowScreenshots: Bool = false, // Privacy-first: no screenshots
        allowCopy: Bool = false, // Privacy-first: no copying
        enableAuditLog: Bool = true,
        restrictedHours: RestrictedHours? = nil
    ) {
        self.requireBiometric = requireBiometric
        self.requirePin = requirePin
        self.sessionTimeout = sessionTimeout
        self.allowScreenshots = allowScreenshots
        self.allowCopy = allowCopy
        self.enableAuditLog = enableAuditLog
        self.restrictedHours = restrictedHours
    }
    
    func isAccessAllowed() -> Bool {
        // Check if current time falls within restricted hours
        if let restricted = restrictedHours {
            return restricted.isCurrentTimeAllowed()
        }
        return true
    }
}

/// Data access log entry for audit trail
struct DataAccessLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let action: String // Type of action performed
    let details: String // Detailed description
    let userId: UUID
    let deviceId: String // Device identifier
    let appVersion: String
    let outcome: ActionOutcome
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        action: String,
        details: String,
        userId: UUID,
        deviceId: String,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
        outcome: ActionOutcome = .success
    ) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.details = details
        self.userId = userId
        self.deviceId = deviceId
        self.appVersion = appVersion
        self.outcome = outcome
    }
}

// MARK: - Supporting Enums for Financial Data Infrastructure

enum DataIntegrityStatus: String, Codable, CaseIterable {
    case unknown = "unknown"
    case valid = "valid"
    case corrupted = "corrupted"
    case repairing = "repairing"
    case repaired = "repaired"
    
    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .valid: return "Valid"
        case .corrupted: return "Corrupted"
        case .repairing: return "Repairing"
        case .repaired: return "Repaired"
        }
    }
}

enum CompressionLevel: String, Codable, CaseIterable {
    case none = "none"
    case fast = "fast"
    case balanced = "balanced"
    case maximum = "maximum"
    
    var displayName: String {
        switch self {
        case .none: return "No Compression"
        case .fast: return "Fast Compression"
        case .balanced: return "Balanced Compression"
        case .maximum: return "Maximum Compression"
        }
    }
}

enum ActionOutcome: String, Codable, CaseIterable {
    case success = "success"
    case failure = "failure"
    case partial = "partial"
    case unauthorized = "unauthorized"
    
    var displayName: String {
        switch self {
        case .success: return "Success"
        case .failure: return "Failure"
        case .partial: return "Partial"
        case .unauthorized: return "Unauthorized"
        }
    }
}

/// Integrity validation record
struct IntegrityValidation: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let status: DataIntegrityStatus
    let details: String
    let dataHash: String
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        status: DataIntegrityStatus,
        details: String,
        dataHash: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.status = status
        self.details = details
        self.dataHash = dataHash
    }
}

/// Time-based access restrictions
struct RestrictedHours: Codable {
    let startHour: Int // 24-hour format (0-23)
    let endHour: Int // 24-hour format (0-23)
    let restrictedDays: [Int] // Days of week (1=Sunday, 7=Saturday)
    
    init(startHour: Int, endHour: Int, restrictedDays: [Int] = []) {
        self.startHour = max(0, min(23, startHour))
        self.endHour = max(0, min(23, endHour))
        self.restrictedDays = restrictedDays
    }
    
    func isCurrentTimeAllowed() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        
        // Check day restrictions
        if restrictedDays.contains(weekday) {
            return false
        }
        
        // Check hour restrictions
        if startHour <= endHour {
            // Same day restriction (e.g., 9 AM to 5 PM)
            return hour < startHour || hour >= endHour
        } else {
            // Overnight restriction (e.g., 10 PM to 6 AM)
            return hour < startHour && hour >= endHour
        }
    }
}

// MARK: - Supporting Models

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case premium = "premium"
    case family = "family"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .family: return "Family"
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return ["Basic expense tracking", "Local data storage", "3 wallets", "1 device"]
        case .premium:
            return ["Unlimited wallets", "Cloud backup", "Advanced analytics", "Export data", "3 devices", "50MB cloud storage"]
        case .family:
            return ["Everything in Premium", "Family sharing", "Multiple users", "Shared budgets", "5 devices", "500MB cloud storage"]
        }
    }
    
    // MARK: - Cloud Storage Features
    
    /// Maximum number of devices allowed for this tier
    var defaultDeviceLimit: Int {
        switch self {
        case .free: return 1
        case .premium: return 3
        case .family: return 5
        }
    }
    
    /// Whether this tier supports multi-device sync
    var supportsMultiDevice: Bool {
        switch self {
        case .free: return false
        case .premium: return true
        case .family: return true
        }
    }
    
    /// Cloud storage quota in bytes
    var cloudStorageQuota: Int {
        switch self {
        case .free: return 0 // No cloud storage
        case .premium: return 50 * 1024 * 1024 // 50MB
        case .family: return 500 * 1024 * 1024 // 500MB
        }
    }
    
    /// Whether this tier supports cloud backup
    var supportsCloudBackup: Bool {
        switch self {
        case .free: return false
        case .premium: return true
        case .family: return true
        }
    }
    
    /// Whether this tier supports advanced sync features
    var supportsAdvancedSync: Bool {
        switch self {
        case .free: return false
        case .premium: return true
        case .family: return true
        }
    }
    
    /// Maximum number of backup versions to keep
    var maxBackupVersions: Int {
        switch self {
        case .free: return 0
        case .premium: return 5
        case .family: return 10
        }
    }
    
    /// Whether this tier supports family sharing
    var supportsFamilySharing: Bool {
        switch self {
        case .free: return false
        case .premium: return false
        case .family: return true
        }
    }
    
    /// Formatted cloud storage quota
    var formattedCloudStorageQuota: String {
        if cloudStorageQuota == 0 {
            return "None"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(cloudStorageQuota))
    }
    
    /// Monthly price for this tier (in USD)
    var monthlyPriceUSD: Double {
        switch self {
        case .free: return 0.0
        case .premium: return 4.99
        case .family: return 9.99
        }
    }
    
    /// Whether user can upgrade from current tier
    func canUpgradeTo(_ tier: SubscriptionTier) -> Bool {
        switch (self, tier) {
        case (.free, .premium), (.free, .family):
            return true
        case (.premium, .family):
            return true
        default:
            return false
        }
    }
}

struct NotificationSettings: Codable {
    var enablePushNotifications: Bool = true
    var dailyReminders: Bool = false
    var weeklyReports: Bool = true
    var budgetAlerts: Bool = true
}

// Placeholder for future features
struct BudgetData: Identifiable, Codable {
    let id: UUID
    let name: String
    let amount: Double
    let period: String
    
    init(name: String, amount: Double, period: String) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.period = period
    }
}

// MARK: - Future Multi-Device Sync Infrastructure
// These models are built-in to support future cross-device sync capabilities
// Currently dormant but designed for seamless activation when needed

/// Device information for future multi-device sync
struct DeviceInfo: Codable, Equatable {
    let id: UUID
    let name: String // "iPhone 15", "iPad Pro", etc.
    let type: DeviceType
    let osVersion: String
    let appVersion: String
    let registeredAt: Date
    var lastActiveAt: Date
    var isCurrentDevice: Bool
    
    init(
        id: UUID = UUID(),
        name: String = UIDevice.current.name,
        type: DeviceType = DeviceType.current(),
        osVersion: String = UIDevice.current.systemVersion,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        registeredAt: Date = Date(),
        lastActiveAt: Date = Date(),
        isCurrentDevice: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.registeredAt = registeredAt
        self.lastActiveAt = lastActiveAt
        self.isCurrentDevice = isCurrentDevice
    }
    
    static func current() -> DeviceInfo {
        return DeviceInfo()
    }
}

enum DeviceType: String, Codable, CaseIterable {
    case iPhone = "iPhone"
    case iPad = "iPad"
    case mac = "Mac"
    case unknown = "Unknown"
    
    static func current() -> DeviceType {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        #elseif os(macOS)
        return .mac
        #else
        return .unknown
        #endif
    }
}

/// Sync metadata for conflict resolution and data integrity
struct SyncMetadata: Codable {
    var lastModified: Date
    var modifiedOnDevice: String
    var syncVersion: Int
    var conflictHash: String
    var conflictResolutionStrategy: ConflictResolutionStrategy
    var deviceSyncEnabled: Bool
    var lastSyncAttempt: Date?
    var syncErrors: [SyncError]
    
    init(
        lastModified: Date = Date(),
        modifiedOnDevice: String = UIDevice.current.name,
        syncVersion: Int = 1,
        conflictHash: String = UUID().uuidString,
        conflictResolutionStrategy: ConflictResolutionStrategy = .lastModifiedWins,
        deviceSyncEnabled: Bool = false,
        lastSyncAttempt: Date? = nil,
        syncErrors: [SyncError] = []
    ) {
        self.lastModified = lastModified
        self.modifiedOnDevice = modifiedOnDevice
        self.syncVersion = syncVersion
        self.conflictHash = conflictHash
        self.conflictResolutionStrategy = conflictResolutionStrategy
        self.deviceSyncEnabled = deviceSyncEnabled
        self.lastSyncAttempt = lastSyncAttempt
        self.syncErrors = syncErrors
    }
    
    static func create() -> SyncMetadata {
        return SyncMetadata()
    }
    
    mutating func markModified(onDevice: String? = nil) {
        lastModified = Date()
        modifiedOnDevice = onDevice ?? UIDevice.current.name
        syncVersion += 1
        conflictHash = UUID().uuidString
    }
}

/// Conflict resolution strategies for future multi-device sync
enum ConflictResolutionStrategy: String, Codable, CaseIterable {
    case lastModifiedWins = "last_modified_wins"     // Use most recently modified version
    case devicePriorityWins = "device_priority_wins" // Primary device wins conflicts
    case manualResolution = "manual_resolution"      // User chooses resolution
    case smartMerge = "smart_merge"                   // AI-assisted intelligent merge
    
    var displayName: String {
        switch self {
        case .lastModifiedWins: return "Last Modified Wins"
        case .devicePriorityWins: return "Primary Device Priority"
        case .manualResolution: return "Manual Resolution"
        case .smartMerge: return "Smart Merge"
        }
    }
}

/// Sync status tracking for individual records
enum RecordSyncStatus: String, Codable, CaseIterable {
    case localOnly = "local_only"           // Not synced, local only
    case pendingSync = "pending_sync"       // Queued for sync
    case syncing = "syncing"               // Currently syncing
    case synced = "synced"                 // Successfully synced
    case conflicted = "conflicted"         // Has sync conflicts
    case failed = "failed"                // Sync failed
    
    var displayName: String {
        switch self {
        case .localOnly: return "Local Only"
        case .pendingSync: return "Pending Sync"
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .conflicted: return "Conflicted"
        case .failed: return "Failed"
        }
    }
}

/// Sync priority for bandwidth and conflict management
enum SyncPriority: String, Codable, CaseIterable {
    case high = "high"           // Transaction changes, important financial data
    case medium = "medium"       // Category changes, notes updates
    case low = "low"            // Metadata changes, analytics data
    case background = "background" // Non-critical updates, can wait
    
    var displayName: String {
        switch self {
        case .high: return "High Priority"
        case .medium: return "Medium Priority"
        case .low: return "Low Priority"
        case .background: return "Background"
        }
    }
    
    var weight: Int {
        switch self {
        case .high: return 100
        case .medium: return 50
        case .low: return 25
        case .background: return 10
        }
    }
}

/// Sync error tracking for debugging and resolution
struct SyncError: Codable, Identifiable {
    let id: UUID
    let errorCode: String
    let errorMessage: String
    let occurredAt: Date
    let attemptedAction: String
    var resolved: Bool
    
    init(
        id: UUID = UUID(),
        errorCode: String,
        errorMessage: String,
        occurredAt: Date = Date(),
        attemptedAction: String,
        resolved: Bool = false
    ) {
        self.id = id
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.occurredAt = occurredAt
        self.attemptedAction = attemptedAction
        self.resolved = resolved
    }
}

/// Conflict resolution log for audit and troubleshooting
struct ConflictResolution: Codable, Identifiable {
    let id: UUID
    let recordId: UUID
    let conflictType: String
    let resolutionStrategy: ConflictResolutionStrategy
    let resolvedAt: Date
    let resolvedBy: String
    let details: String
    
    init(
        id: UUID = UUID(),
        recordId: UUID,
        conflictType: String,
        resolutionStrategy: ConflictResolutionStrategy,
        resolvedAt: Date = Date(),
        resolvedBy: String = UIDevice.current.name,
        details: String
    ) {
        self.id = id
        self.recordId = recordId
        self.conflictType = conflictType
        self.resolutionStrategy = resolutionStrategy
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
        self.details = details
    }
}

// MARK: - Legacy User Data Model (Deprecated)
// This will be gradually phased out in favor of UserProfile + LocalFinancialData

struct UserData: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var transactions: [Txn] // User's transactions (income/expenses)
    var accounts: [AccountData] // Multiple businesses/wallets
    let createdAt: Date
    var updatedAt: Date
    
    // User preferences and settings
    var goals: String? // User's selected goals from onboarding (comma-separated)
    
    // Firebase sync preference - true by default for existing users
    var enableFirebaseSync: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        transactions: [Txn] = [],
        accounts: [AccountData] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        goals: String? = nil,
        enableFirebaseSync: Bool = true // Default to enabled for new users
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.transactions = transactions
        self.accounts = accounts
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.goals = goals
        self.enableFirebaseSync = enableFirebaseSync
    }
    
    // Auto-calculated balance from all transactions (income - expenses)
    var userBalance: Double {
        return transactions.reduce(0) { $0 + $1.amount }
    }
    
    // Add transaction and update timestamp
    mutating func addTransaction(_ transaction: Txn) {
        print("📦 UserData: ADD TRANSACTION TO MODEL")
        print("📊 UserData: Current transactions count before add: \(transactions.count)")
        
        transactions.append(transaction)
        updatedAt = Date()
        
        print("📊 UserData: Current transactions count after add: \(transactions.count)")
        print("✅ UserData: Transaction added to model successfully")
        print("🕒 UserData: Updated timestamp to: \(updatedAt)")
    }
    
    // Remove transaction and update timestamp
    mutating func removeTransaction(withId id: UUID) {
        transactions.removeAll { $0.id == id }
        updatedAt = Date()
    }
    
    // Update existing transaction
    mutating func updateTransaction(_ updatedTransaction: Txn) {
        if let index = transactions.firstIndex(where: { $0.id == updatedTransaction.id }) {
            transactions[index] = updatedTransaction
            updatedAt = Date()
        }
    }
    
    // Get transactions for specific wallet
    func transactions(for walletId: UUID) -> [Txn] {
        return transactions.filter { $0.walletID == walletId }
    }
    
    // Get balance for specific wallet
    func balance(for walletId: UUID) -> Double {
        return transactions(for: walletId).reduce(0) { $0 + $1.amount }
    }
    
    // Add account
    mutating func addAccount(_ account: AccountData) {
        accounts.append(account)
        updatedAt = Date()
    }
    
    // Remove account (and optionally reassign transactions)
    mutating func removeAccount(withId accountId: UUID, reassignToAccountId: UUID? = nil) {
        accounts.removeAll { $0.id == accountId }
        
        // Reassign transactions to another wallet or set to nil
        for index in transactions.indices {
            if transactions[index].walletID == accountId {
                transactions[index] = Txn(
                    txID: transactions[index].txID,
                    accountID: transactions[index].accountID,
                    walletID: reassignToAccountId,
                    category: transactions[index].category,
                    categoryId: transactions[index].categoryId,
                    amount: transactions[index].amount,
                    date: transactions[index].date,
                    createdAt: transactions[index].createdAt,
                    receiptImage: transactions[index].receiptImage,
                    hasReceiptImage: transactions[index].hasReceiptImage,
                    merchantName: transactions[index].merchantName,
                    paymentMethod: transactions[index].paymentMethod,
                    receiptNumber: transactions[index].receiptNumber,
                    invoiceNumber: transactions[index].invoiceNumber,
                    items: transactions[index].items,
                    note: transactions[index].note,
                    originalAmount: transactions[index].originalAmount,
                    originalCurrency: transactions[index].originalCurrency,
                    primaryCurrency: transactions[index].primaryCurrency,
                    secondaryCurrency: transactions[index].secondaryCurrency,
                    exchangeRate: transactions[index].exchangeRate,
                    secondaryAmount: transactions[index].secondaryAmount,
                    secondaryExchangeRate: transactions[index].secondaryExchangeRate
                )
            }
        }
        
        updatedAt = Date()
    }
    
    // Get default account (first account marked as default, or first account if none marked)
    var defaultAccount: AccountData? {
        return accounts.first { $0.isDefault } ?? accounts.first
    }
    
    // MARK: - Custom Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id, name, email, accounts, createdAt, updatedAt, enableFirebaseSync
        // Note: transactions excluded because Txn contains UIImage which isn't Codable
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        accounts = try container.decode([AccountData].self, forKey: .accounts)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        // Default to true for backward compatibility with existing users
        enableFirebaseSync = try container.decodeIfPresent(Bool.self, forKey: .enableFirebaseSync) ?? true
        transactions = [] // Initialize empty, will be loaded separately
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(enableFirebaseSync, forKey: .enableFirebaseSync)
        // Note: transactions not encoded due to UIImage
    }
}

// MARK: - Account Data Model

struct AccountData: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: AccountType
    var currency: Currency
    var isDefault: Bool
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType = .personal,
        currency: Currency = .php,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.currency = currency
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AccountType: String, CaseIterable, Codable {
    case personal = "Personal"
    case business = "Business"
    case savings = "Savings"
    case investment = "Investment"
    case wallet = "Wallet"
    case creditCard = "Credit Card"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .business: return "building.2.fill"
        case .savings: return "banknote.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .wallet: return "wallet.fill"
        case .creditCard: return "creditcard.fill"
        }
    }
}

// MARK: - Receipt Item Model

struct ReceiptItem: Equatable, Hashable, Codable {
    let description: String
    let quantity: Int
    let unitPrice: Double
    let totalPrice: Double
}

// MARK: - Transaction Model

struct Txn: Identifiable, Equatable, Hashable, Codable {
    let txID: UUID // This transaction's unique ID
    let accountID: UUID // Which user this belongs to  
    let walletID: UUID? // Which wallet from a specific user this belongs to
    
    // Identifiable conformance
    var id: UUID { txID }
    
    // Backward compatibility properties
    var userId: UUID { accountID }
    var accountId: UUID? { walletID }
    let category: String // Keep for backward compatibility and UI display
    let categoryId: UUID? // New ID-based lookup for performance
    let amount: Double // negative for expense (in primary currency)
    let date: Date
    let createdAt: Date // when the transaction was added to the app
    let receiptImage: UIImage? // Deprecated: Use hasReceiptImage + ImageCacheManager for new code
    let hasReceiptImage: Bool // Performance optimization: indicates if receipt exists in cache
    let merchantName: String?
    let paymentMethod: String?
    let receiptNumber: String?
    let invoiceNumber: String?
    let items: [ReceiptItem]
    let note: String? // User-added note/context for the transaction
    
    // Currency conversion fields
    let originalAmount: Double? // original amount from receipt
    let originalCurrency: Currency? // currency from receipt
    let primaryCurrency: Currency // user's primary currency
    let secondaryCurrency: Currency? // user's secondary currency
    let exchangeRate: Double? // conversion rate used (original -> primary)
    let secondaryAmount: Double? // amount in secondary currency
    let secondaryExchangeRate: Double? // conversion rate used (primary -> secondary)
    
    // User entry context fields (NEW - for better currency display)
    let userEnteredAmount: Double? // amount user actually entered ($10)
    let userEnteredCurrency: Currency? // currency user was working in when entering
    
    // MARK: - Privacy-First Sync Infrastructure (Dormant)
    // Future multi-device sync capabilities - currently local-only by default
    
    var syncMetadata: SyncMetadata // Sync state and conflict resolution
    var syncStatus: RecordSyncStatus // Current sync status (defaults to localOnly)
    var isLocalOnly: Bool // Privacy flag - true = never sync, false = may sync if user enables
    var syncPriority: SyncPriority // Priority for when sync is enabled
    
    init(
        txID: UUID = UUID(),
        accountID: UUID,
        walletID: UUID? = nil,
        category: String,
        categoryId: UUID? = nil, 
        amount: Double, 
        date: Date, 
        createdAt: Date = Date(),
        receiptImage: UIImage? = nil, 
        hasReceiptImage: Bool = false,
        merchantName: String? = nil, 
        paymentMethod: String? = nil, 
        receiptNumber: String? = nil,
        invoiceNumber: String? = nil,
        items: [ReceiptItem] = [],
        note: String? = nil,
        originalAmount: Double? = nil,
        originalCurrency: Currency? = nil,
        primaryCurrency: Currency = .php,
        secondaryCurrency: Currency? = nil,
        exchangeRate: Double? = nil,
        secondaryAmount: Double? = nil,
        secondaryExchangeRate: Double? = nil,
        // User entry context (NEW)
        userEnteredAmount: Double? = nil,
        userEnteredCurrency: Currency? = nil,
        // Privacy-first sync parameters (dormant by default)
        syncMetadata: SyncMetadata? = nil,
        syncStatus: RecordSyncStatus = .localOnly,
        isLocalOnly: Bool = true, // Privacy-first: local only by default
        syncPriority: SyncPriority = .high // Important financial data gets high priority when sync is enabled
    ) {
        self.txID = txID
        self.accountID = accountID
        self.walletID = walletID
        self.category = category
        // Safe category ID lookup with fallback
        self.categoryId = categoryId ?? CategoriesManager.shared.getCategoryId(for: category)
        self.amount = amount
        self.date = date
        self.createdAt = createdAt
        self.receiptImage = receiptImage
        self.hasReceiptImage = hasReceiptImage || receiptImage != nil // Auto-detect if image provided
        self.merchantName = merchantName
        self.paymentMethod = paymentMethod
        self.receiptNumber = receiptNumber
        self.invoiceNumber = invoiceNumber
        self.items = items
        self.note = note
        self.originalAmount = originalAmount
        self.originalCurrency = originalCurrency
        self.primaryCurrency = primaryCurrency
        self.secondaryCurrency = secondaryCurrency
        self.exchangeRate = exchangeRate
        self.secondaryAmount = secondaryAmount
        self.secondaryExchangeRate = secondaryExchangeRate
        self.userEnteredAmount = userEnteredAmount
        self.userEnteredCurrency = userEnteredCurrency
        
        // Initialize sync infrastructure (dormant by default)
        self.syncMetadata = syncMetadata ?? SyncMetadata.create()
        self.syncStatus = syncStatus
        self.isLocalOnly = isLocalOnly
        self.syncPriority = syncPriority
        
        // Store receipt image in cache if provided
        if let image = receiptImage {
            ImageCacheManager.shared.storeReceiptImage(image, for: txID)
        }
    }
    
    // MARK: - Backward Compatibility Initializers
    
    // Legacy initializer with old field names for backward compatibility
    init(
        id: UUID = UUID(),
        userId: UUID,
        category: String,
        categoryId: UUID? = nil,
        amount: Double,
        date: Date,
        createdAt: Date = Date(),
        receiptImage: UIImage? = nil,
        hasReceiptImage: Bool = false,
        merchantName: String? = nil,
        paymentMethod: String? = nil,
        receiptNumber: String? = nil,
        invoiceNumber: String? = nil,
        items: [ReceiptItem] = [],
        note: String? = nil,
        accountId: UUID? = nil,
        originalAmount: Double? = nil,
        originalCurrency: Currency? = nil,
        primaryCurrency: Currency = .php,
        secondaryCurrency: Currency? = nil,
        exchangeRate: Double? = nil,
        secondaryAmount: Double? = nil,
        secondaryExchangeRate: Double? = nil,
        // Legacy sync defaults - inherit privacy-first defaults
        syncMetadata: SyncMetadata? = nil,
        syncStatus: RecordSyncStatus = .localOnly,
        isLocalOnly: Bool = true,
        syncPriority: SyncPriority = .high
    ) {
        self.init(
            txID: id,
            accountID: userId,
            walletID: accountId,
            category: category,
            categoryId: categoryId,
            amount: amount,
            date: date,
            createdAt: createdAt,
            receiptImage: receiptImage,
            hasReceiptImage: hasReceiptImage,
            merchantName: merchantName,
            paymentMethod: paymentMethod,
            receiptNumber: receiptNumber,
            invoiceNumber: invoiceNumber,
            items: items,
            note: note,
            originalAmount: originalAmount,
            originalCurrency: originalCurrency,
            primaryCurrency: primaryCurrency,
            secondaryCurrency: secondaryCurrency,
            exchangeRate: exchangeRate,
            secondaryAmount: secondaryAmount,
            secondaryExchangeRate: secondaryExchangeRate,
            // Pass through sync parameters
            syncMetadata: syncMetadata,
            syncStatus: syncStatus,
            isLocalOnly: isLocalOnly,
            syncPriority: syncPriority
        )
    }
    
    // Helper computed property to check if conversion occurred
    var wasConverted: Bool {
        return originalAmount != nil && originalCurrency != nil && originalCurrency != primaryCurrency
    }
    
    // MARK: - Codable Implementation (exclude UIImage)
    
    enum CodingKeys: String, CodingKey {
        case txID, accountID, walletID, category, categoryId, amount, date, createdAt
        case hasReceiptImage, merchantName, paymentMethod, receiptNumber, invoiceNumber, items, note
        case originalAmount, originalCurrency, primaryCurrency, secondaryCurrency
        case exchangeRate, secondaryAmount, secondaryExchangeRate
        case userEnteredAmount, userEnteredCurrency
        // Privacy-first sync infrastructure fields
        case syncMetadata, syncStatus, isLocalOnly, syncPriority
        // Note: receiptImage is excluded as UIImage is not Codable
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        txID = try container.decode(UUID.self, forKey: .txID)
        accountID = try container.decode(UUID.self, forKey: .accountID)
        walletID = try container.decodeIfPresent(UUID.self, forKey: .walletID)
        category = try container.decode(String.self, forKey: .category)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        amount = try container.decode(Double.self, forKey: .amount)
        date = try container.decode(Date.self, forKey: .date)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // receiptImage is always nil when decoding (not stored)
        receiptImage = nil
        
        hasReceiptImage = try container.decodeIfPresent(Bool.self, forKey: .hasReceiptImage) ?? false
        merchantName = try container.decodeIfPresent(String.self, forKey: .merchantName)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod)
        receiptNumber = try container.decodeIfPresent(String.self, forKey: .receiptNumber)
        invoiceNumber = try container.decodeIfPresent(String.self, forKey: .invoiceNumber)
        items = try container.decodeIfPresent([ReceiptItem].self, forKey: .items) ?? []
        note = try container.decodeIfPresent(String.self, forKey: .note)
        
        originalAmount = try container.decodeIfPresent(Double.self, forKey: .originalAmount)
        originalCurrency = try container.decodeIfPresent(Currency.self, forKey: .originalCurrency)
        primaryCurrency = try container.decode(Currency.self, forKey: .primaryCurrency)
        secondaryCurrency = try container.decodeIfPresent(Currency.self, forKey: .secondaryCurrency)
        exchangeRate = try container.decodeIfPresent(Double.self, forKey: .exchangeRate)
        secondaryAmount = try container.decodeIfPresent(Double.self, forKey: .secondaryAmount)
        secondaryExchangeRate = try container.decodeIfPresent(Double.self, forKey: .secondaryExchangeRate)
        userEnteredAmount = try container.decodeIfPresent(Double.self, forKey: .userEnteredAmount)
        userEnteredCurrency = try container.decodeIfPresent(Currency.self, forKey: .userEnteredCurrency)
        
        // Privacy-first sync infrastructure (with backward compatibility)
        syncMetadata = try container.decodeIfPresent(SyncMetadata.self, forKey: .syncMetadata) ?? SyncMetadata.create()
        syncStatus = try container.decodeIfPresent(RecordSyncStatus.self, forKey: .syncStatus) ?? .localOnly
        isLocalOnly = try container.decodeIfPresent(Bool.self, forKey: .isLocalOnly) ?? true // Privacy-first default
        syncPriority = try container.decodeIfPresent(SyncPriority.self, forKey: .syncPriority) ?? .high
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(txID, forKey: .txID)
        try container.encode(accountID, forKey: .accountID)
        try container.encodeIfPresent(walletID, forKey: .walletID)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encode(amount, forKey: .amount)
        try container.encode(date, forKey: .date)
        try container.encode(createdAt, forKey: .createdAt)
        
        // receiptImage is intentionally not encoded (UIImage not Codable)
        
        try container.encode(hasReceiptImage, forKey: .hasReceiptImage)
        try container.encodeIfPresent(merchantName, forKey: .merchantName)
        try container.encodeIfPresent(paymentMethod, forKey: .paymentMethod)
        try container.encodeIfPresent(receiptNumber, forKey: .receiptNumber)
        try container.encodeIfPresent(invoiceNumber, forKey: .invoiceNumber)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(note, forKey: .note)
        
        try container.encodeIfPresent(originalAmount, forKey: .originalAmount)
        try container.encodeIfPresent(originalCurrency, forKey: .originalCurrency)
        try container.encode(primaryCurrency, forKey: .primaryCurrency)
        try container.encodeIfPresent(secondaryCurrency, forKey: .secondaryCurrency)
        try container.encodeIfPresent(exchangeRate, forKey: .exchangeRate)
        try container.encodeIfPresent(secondaryAmount, forKey: .secondaryAmount)
        try container.encodeIfPresent(secondaryExchangeRate, forKey: .secondaryExchangeRate)
        try container.encodeIfPresent(userEnteredAmount, forKey: .userEnteredAmount)
        try container.encodeIfPresent(userEnteredCurrency, forKey: .userEnteredCurrency)
        
        // Privacy-first sync infrastructure
        try container.encode(syncMetadata, forKey: .syncMetadata)
        try container.encode(syncStatus, forKey: .syncStatus)
        try container.encode(isLocalOnly, forKey: .isLocalOnly)
        try container.encode(syncPriority, forKey: .syncPriority)
    }
    
    // MARK: - Image Cache Integration
    
    /// Load receipt image from cache (async)
    func loadReceiptImage(completion: @escaping (UIImage?) -> Void) {
        if hasReceiptImage {
            ImageCacheManager.shared.retrieveReceiptImage(for: id, completion: completion)
        } else {
            completion(receiptImage) // Fallback to legacy stored image
        }
    }
    
    /// Store new receipt image and return updated transaction
    func withReceiptImage(_ image: UIImage) -> Txn {
        ImageCacheManager.shared.storeReceiptImage(image, for: id)
        return Txn(
            id: id,
            userId: userId,
            category: category,
            amount: amount,
            date: date,
            createdAt: createdAt,
            receiptImage: nil, // Don't store in memory
            hasReceiptImage: true,
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
    
    /// Remove receipt image and return updated transaction
    func withoutReceiptImage() -> Txn {
        ImageCacheManager.shared.removeReceiptImage(for: id)
        return Txn(
            id: id,
            userId: userId,
            category: category,
            amount: amount,
            date: date,
            createdAt: createdAt,
            receiptImage: nil,
            hasReceiptImage: false,
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
    
    // Custom Equatable implementation (UIImage doesn't conform to Equatable)
    static func == (lhs: Txn, rhs: Txn) -> Bool {
        return lhs.id == rhs.id &&
               lhs.userId == rhs.userId &&
               lhs.category == rhs.category &&
               lhs.amount == rhs.amount &&
               lhs.date == rhs.date &&
               lhs.createdAt == rhs.createdAt &&
               lhs.merchantName == rhs.merchantName &&
               lhs.paymentMethod == rhs.paymentMethod &&
               lhs.receiptNumber == rhs.receiptNumber &&
               lhs.invoiceNumber == rhs.invoiceNumber &&
               lhs.items == rhs.items &&
               lhs.note == rhs.note &&
               lhs.accountId == rhs.accountId &&
               lhs.originalAmount == rhs.originalAmount &&
               lhs.originalCurrency == rhs.originalCurrency &&
               lhs.primaryCurrency == rhs.primaryCurrency &&
               lhs.secondaryCurrency == rhs.secondaryCurrency &&
               lhs.exchangeRate == rhs.exchangeRate &&
               lhs.secondaryAmount == rhs.secondaryAmount &&
               lhs.secondaryExchangeRate == rhs.secondaryExchangeRate &&
               lhs.hasReceiptImage == rhs.hasReceiptImage &&
               // Privacy-first sync infrastructure
               lhs.syncStatus == rhs.syncStatus &&
               lhs.isLocalOnly == rhs.isLocalOnly &&
               lhs.syncPriority == rhs.syncPriority
        // Note: receiptImage excluded (UIImage not Equatable), syncMetadata excluded (contains Dates that change frequently)
    }
    
    // Custom Hashable implementation (UIImage doesn't conform to Hashable)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(userId)
        hasher.combine(category)
        hasher.combine(amount)
        hasher.combine(date)
        hasher.combine(createdAt)
        hasher.combine(merchantName)
        hasher.combine(paymentMethod)
        hasher.combine(receiptNumber)
        hasher.combine(invoiceNumber)
        hasher.combine(items)
        hasher.combine(note)
        hasher.combine(accountId)
        hasher.combine(originalAmount)
        hasher.combine(originalCurrency)
        hasher.combine(primaryCurrency)
        hasher.combine(secondaryCurrency)
        hasher.combine(exchangeRate)
        hasher.combine(secondaryAmount)
        hasher.combine(secondaryExchangeRate)
        hasher.combine(hasReceiptImage)
        // Privacy-first sync infrastructure
        hasher.combine(syncStatus)
        hasher.combine(isLocalOnly)
        hasher.combine(syncPriority)
        // Note: receiptImage and syncMetadata excluded (not hashable or change frequently)
    }
    
    // MARK: - Privacy-First Sync Methods
    
    /// Mark transaction as modified for future sync (when enabled)
    mutating func markAsModified(onDevice: String? = nil) {
        syncMetadata.markModified(onDevice: onDevice)
        if !isLocalOnly {
            syncStatus = .pendingSync
        }
    }
    
    /// Enable sync for this transaction (user must explicitly allow)
    mutating func enableSync(priority: SyncPriority = .high) {
        isLocalOnly = false
        syncPriority = priority
        syncStatus = .pendingSync
        markAsModified()
    }
    
    /// Force transaction to remain local-only (privacy protection)
    mutating func forceLocalOnly() {
        isLocalOnly = true
        syncStatus = .localOnly
        markAsModified()
    }
    
    /// Check if transaction can be synced (respects privacy settings)
    var canSync: Bool {
        return !isLocalOnly && syncMetadata.deviceSyncEnabled
    }
    
    /// Check if transaction needs sync (has pending changes)
    var needsSync: Bool {
        return canSync && (syncStatus == .pendingSync || syncStatus == .failed)
    }
    
    /// Create sync-ready copy with updated metadata
    func preparingForSync(toDevice device: String) -> Txn {
        var syncedTransaction = self
        syncedTransaction.syncStatus = .syncing
        syncedTransaction.syncMetadata.lastSyncAttempt = Date()
        syncedTransaction.markAsModified(onDevice: device)
        return syncedTransaction
    }
    
    /// Mark sync as successful
    mutating func markSyncSuccessful() {
        if canSync {
            syncStatus = .synced
            syncMetadata.syncErrors.removeAll()
        }
    }
    
    /// Mark sync as failed with error
    mutating func markSyncFailed(error: SyncError) {
        if canSync {
            syncStatus = .failed
            syncMetadata.syncErrors.append(error)
        }
    }
    
    /// Check if transaction has sync conflicts
    var hasConflicts: Bool {
        return syncStatus == .conflicted
    }
    
    /// Get sync priority weight for queue management
    var syncWeight: Int {
        return syncPriority.weight
    }
}

// MARK: - Currency Model

enum Currency: String, CaseIterable, Codable {
    case php = "PHP"
    case usd = "USD"
    case gbp = "GBP"
    case eur = "EUR"
    case cad = "CAD"
    case jpy = "JPY"
    case aud = "AUD"
    case brl = "BRL"
    case sgd = "SGD"
    case zar = "ZAR"
    case cny = "CNY"
    case inr = "INR"
    case krw = "KRW"
    case mxn = "MXN"
    case chf = "CHF"
    case nok = "NOK"
    case sek = "SEK"
    case dkk = "DKK"
    case hkd = "HKD"
    case nzd = "NZD"
    case thb = "THB"
    case myr = "MYR"
    case idr = "IDR"
    case vnd = "VND"
    case rub = "RUB"
    case pln = "PLN"
    case czk = "CZK"
    case huf = "HUF"
    case try_ = "TRY"
    case aed = "AED"

    var symbol: String {
        switch self {
        case .php: return "₱"
        case .usd, .cad, .aud, .sgd, .hkd, .nzd, .mxn: return "$"
        case .gbp: return "£"
        case .eur: return "€"
        case .jpy, .cny: return "¥"
        case .brl: return "R$"
        case .zar: return "R"
        case .inr: return "₹"
        case .krw: return "₩"
        case .chf: return "CHF"
        case .nok: return "kr"
        case .sek: return "kr"
        case .dkk: return "kr"
        case .thb: return "฿"
        case .myr: return "RM"
        case .idr: return "Rp"
        case .vnd: return "₫"
        case .rub: return "₽"
        case .pln: return "zł"
        case .czk: return "Kč"
        case .huf: return "Ft"
        case .try_: return "₺"
        case .aed: return "د.إ"
        }
    }

    var flag: String {
        switch self {
        case .php: return "🇵🇭"
        case .usd: return "🇺🇸"
        case .gbp: return "🇬🇧"
        case .eur: return "🇪🇺"
        case .cad: return "🇨🇦"
        case .jpy: return "🇯🇵"
        case .aud: return "🇦🇺"
        case .brl: return "🇧🇷"
        case .sgd: return "🇸🇬"
        case .zar: return "🇿🇦"
        case .cny: return "🇨🇳"
        case .inr: return "🇮🇳"
        case .krw: return "🇰🇷"
        case .mxn: return "🇲🇽"
        case .chf: return "🇨🇭"
        case .nok: return "🇳🇴"
        case .sek: return "🇸🇪"
        case .dkk: return "🇩🇰"
        case .hkd: return "🇭🇰"
        case .nzd: return "🇳🇿"
        case .thb: return "🇹🇭"
        case .myr: return "🇲🇾"
        case .idr: return "🇮🇩"
        case .vnd: return "🇻🇳"
        case .rub: return "🇷🇺"
        case .pln: return "🇵🇱"
        case .czk: return "🇨🇿"
        case .huf: return "🇭🇺"
        case .try_: return "🇹🇷"
        case .aed: return "🇦🇪"
        }
    }

    var displayName: String {
        switch self {
        case .php: return "₱ - PHP"
        case .usd: return "$ - USD"
        case .gbp: return "£ - GBP"
        case .eur: return "€ - EUR"
        case .cad: return "$ - CAD"
        case .jpy: return "¥ - JPY"
        case .aud: return "$ - AUD"
        case .brl: return "R$ - BRL"
        case .sgd: return "$ - SGD"
        case .zar: return "R - ZAR"
        case .cny: return "¥ - CNY"
        case .inr: return "₹ - INR"
        case .krw: return "₩ - KRW"
        case .mxn: return "$ - MXN"
        case .chf: return "CHF - CHF"
        case .nok: return "kr - NOK"
        case .sek: return "kr - SEK"
        case .dkk: return "kr - DKK"
        case .hkd: return "$ - HKD"
        case .nzd: return "$ - NZD"
        case .thb: return "฿ - THB"
        case .myr: return "RM - MYR"
        case .idr: return "Rp - IDR"
        case .vnd: return "₫ - VND"
        case .rub: return "₽ - RUB"
        case .pln: return "zł - PLN"
        case .czk: return "Kč - CZK"
        case .huf: return "Ft - HUF"
        case .try_: return "₺ - TRY"
        case .aed: return "د.إ - AED"
        }
    }
}

// MARK: - Language Model

enum Language: String, CaseIterable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case italian = "Italian"
    case portuguese = "Portuguese"
    case dutch = "Dutch"
    case russian = "Russian"
    case chinese = "Chinese"
    case japanese = "Japanese"
    case korean = "Korean"
    case arabic = "Arabic"
    case hindi = "Hindi"
    case thai = "Thai"
    case vietnamese = "Vietnamese"
    case indonesian = "Indonesian"
    case malay = "Malay"
    case tagalog = "Tagalog"
    case danish = "Danish"
    case norwegian = "Norwegian"
    case swedish = "Swedish"
    case finnish = "Finnish"
    case polish = "Polish"
    case czech = "Czech"
    case hungarian = "Hungarian"
    case turkish = "Turkish"
    case greek = "Greek"
    case hebrew = "Hebrew"
    case ukrainian = "Ukrainian"
    
    var displayName: String {
        return rawValue
    }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .dutch: return "🇳🇱"
        case .russian: return "🇷🇺"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        case .thai: return "🇹🇭"
        case .vietnamese: return "🇻🇳"
        case .indonesian: return "🇮🇩"
        case .malay: return "🇲🇾"
        case .tagalog: return "🇵🇭"
        case .danish: return "🇩🇰"
        case .norwegian: return "🇳🇴"
        case .swedish: return "🇸🇪"
        case .finnish: return "🇫🇮"
        case .polish: return "🇵🇱"
        case .czech: return "🇨🇿"
        case .hungarian: return "🇭🇺"
        case .turkish: return "🇹🇷"
        case .greek: return "🇬🇷"
        case .hebrew: return "🇮🇱"
        case .ukrainian: return "🇺🇦"
        }
    }
}