//
//  SubscriptionManager.swift
//  CashMonki
//
//  Manages subscriptions: storage, auto-generation, and reminders
//

import Foundation
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    @Published var subscriptions: [Subscription] = []
    @Published var upcomingSubscriptions: [Subscription] = [] // Due in next 7 days

    // MARK: - Free Tier Limits

    /// Maximum number of subscriptions for free users
    static let maxFreeSubscriptions = 2

    /// Check if user can add more subscriptions (Pro users unlimited, free users limited to 2)
    var canAddMoreSubscriptions: Bool {
        let isProUser = RevenueCatManager.shared.isProUser
        let currentCount = subscriptions.count
        let canAdd = isProUser || currentCount < Self.maxFreeSubscriptions
        print("🔐 SubscriptionManager.canAddMoreSubscriptions: isProUser=\(isProUser), count=\(currentCount), max=\(Self.maxFreeSubscriptions), canAdd=\(canAdd)")
        if isProUser {
            return true
        }
        // Allow adding if current count is less than max (0 or 1 can add, 2 cannot)
        return currentCount < Self.maxFreeSubscriptions
    }

    /// Number of remaining free subscription slots
    var remainingFreeSlots: Int {
        if RevenueCatManager.shared.isProUser {
            return Int.max
        }
        return max(0, Self.maxFreeSubscriptions - subscriptions.count)
    }

    // MARK: - Private Properties

    /// Legacy global key (pre per-user scoping). Kept only for one-time migration.
    nonisolated static let legacyGlobalKey = "cashmonki_subscriptions"
    private var cancellables = Set<AnyCancellable>()

    /// Per-user storage key. Subscriptions are scoped to the signed-in user (or guest) so
    /// they never leak across accounts. Uses the SAME UID that transactions are keyed by
    /// (`last_authenticated_firebase_uid`), so subs stay aligned with the user's data.
    nonisolated static func storageKey() -> String {
        let uid = UserDefaults.standard.string(forKey: "last_authenticated_firebase_uid")
            ?? UserDefaults.standard.string(forKey: "currentUserId")
            ?? "guest"
        return "\(legacyGlobalKey)_\(uid)"
    }

    /// Nonisolated snapshot of the persisted subscriptions, for background/tool reads that
    /// can't touch the @MainActor `subscriptions` property. Persistence is saved on every
    /// mutation, so this stays current. UserDefaults access is thread-safe.
    nonisolated static func persistedSubscriptions() -> [Subscription] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey()),
              let decoded = try? JSONDecoder().decode([Subscription].self, from: data)
        else { return [] }
        return decoded.filter { !$0.isDeleted }
    }

    /// Soft-deleted subscriptions. Kept OUT of `subscriptions` so no view can ever render one,
    /// but persisted and pushed so the deletion reaches the account's other devices. Without this
    /// the other device just re-uploads its live copy and the subscription comes back.
    private var deletedRecords: [Subscription] = []

    /// Newest-first cap so the graveyard can't grow without bound. Generous on purpose: dropping
    /// a tombstone lets another device re-upload that subscription, so the cap is a last resort,
    /// not routine housekeeping.
    private static let deletedCap = 2_000

    /// Everything that gets persisted and pushed: live rows plus tombstoned ones.
    private var allRecords: [Subscription] { subscriptions + deletedRecords }

    /// Split a decoded/merged record set into the live list and the graveyard.
    private func applyRecords(_ records: [Subscription]) {
        subscriptions = records.filter { !$0.isDeleted }
        deletedRecords = records.filter { $0.isDeleted }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(Self.deletedCap)
            .map { $0 }
    }

    /// Record-level last-write-wins, the same rule categories use. A tombstone is just a record
    /// with a newer `updatedAt`, so a delete beats an older edit and a newer edit beats an older
    /// delete. Returns nil when nothing actually changed, so echoing our own push back is a no-op.
    private func mergedRecords(with incoming: [Subscription]) -> [Subscription]? {
        var byId: [UUID: Subscription] = [:]
        for r in allRecords { byId[r.id] = r }
        var changed = false
        for r in incoming {
            if let mine = byId[r.id] {
                guard r.updatedAt > mine.updatedAt else { continue }
            }
            byId[r.id] = r
            changed = true
        }
        return changed ? Array(byId.values) : nil
    }

    // MARK: - Initialization

    private init() {
        loadSubscriptions()
        setupAutoRefresh()
    }

    // MARK: - Storage

    private func loadSubscriptions() {
        migrateGlobalSubscriptionsIfNeeded()
        let key = Self.storageKey()
        if let data = UserDefaults.standard.data(forKey: key) {
            do {
                let decoded = try JSONDecoder().decode([Subscription].self, from: data)
                applyRecords(decoded)
                updateUpcoming()
                print("📋 SubscriptionManager: Loaded \(subscriptions.count) subscriptions (key: \(key))")
            } catch {
                print("❌ SubscriptionManager: Failed to decode subscriptions - \(error)")
                subscriptions = []
                deletedRecords = []
                updateUpcoming()
            }
        } else if AuthenticationManager.shared.isGuestMode,
                  let backup = UserDefaults.standard.data(forKey: Self.legacyGlobalKey + "_legacy_backup"),
                  let decoded = try? JSONDecoder().decode([Subscription].self, from: backup),
                  !decoded.isEmpty {
            // Guest (not-connected) identity with no subs under its own key: recover the
            // original pre-split subscriptions from the backup — they belong to this local
            // data. Persist under the guest key so it's stable from here on.
            applyRecords(decoded)
            UserDefaults.standard.set(backup, forKey: key)
            updateUpcoming()
            print("📋 SubscriptionManager: recovered \(decoded.count) subs from legacy backup for guest (key: \(key))")
        } else {
            // No data for THIS user — start empty (do not inherit the previous user's list).
            subscriptions = []
            deletedRecords = []
            updateUpcoming()
            print("📋 SubscriptionManager: No subscriptions for current user (key: \(key))")
        }
    }

    /// Reload subscriptions for whoever is the current user. Call on login / user switch.
    /// Loads the local per-user copy first, then merges the cloud copy (returning user on a
    /// fresh install) — same local-first + cloud-backup model as transactions.
    func reloadForCurrentUser() {
        loadSubscriptions()
        mergeCloudSubscriptions()
    }

    /// Pull the cloud subscriptions doc and union it into the local set (by id), then persist.
    private func mergeCloudSubscriptions() {
        guard UserManager.shared.currentUser.enableFirebaseSync else { return }
        let uid = UserManager.shared.syncUID()
        FirestoreService.shared.fetchSubscriptions(userId: uid) { [weak self] result in
            guard case .success(let data?) = result,
                  let cloud = try? JSONDecoder().decode([Subscription].self, from: data),
                  !cloud.isEmpty else { return }
            Task { @MainActor in
                guard let self = self else { return }
                if let merged = self.mergedRecords(with: cloud) {
                    self.applyRecords(merged)
                    self.saveSubscriptions()  // persists + re-pushes the merged set
                } else {
                    self.updateUpcoming()
                }
            }
        }
    }

    /// Apply a subscriptions blob pushed by the live listener (CloudSync). Union by id, same as
    /// the one-shot merge, so re-receiving our own write is a no-op.
    @MainActor
    func applyCloudSubscriptions(_ data: Data) {
        guard UserManager.shared.currentUser.enableFirebaseSync,
              let cloud = try? JSONDecoder().decode([Subscription].self, from: data),
              !cloud.isEmpty else { return }

        guard let merged = mergedRecords(with: cloud) else { return }
        applyRecords(merged)
        saveSubscriptions()
        print("📡 CloudSync: applied \(cloud.count) cloud subscriptions → \(subscriptions.count) live")
    }

    /// Bring another box's subscriptions into the current user's set (union by id), then
    /// persist under the current user's key. Used when connecting a chosen device data box.
    func adoptSubscriptions(fromUID uid: String) {
        guard let data = UserDefaults.standard.data(forKey: "\(Self.legacyGlobalKey)_\(uid)"),
              let incoming = try? JSONDecoder().decode([Subscription].self, from: data),
              !incoming.isEmpty else { return }
        if let merged = mergedRecords(with: incoming) { applyRecords(merged) }
        saveSubscriptions()
        print("📋 SubscriptionManager: adopted \(incoming.count) subscriptions from box \(uid.prefix(8))")
    }

    private func saveSubscriptions() {
        do {
            // Persist and push live rows AND tombstones — the tombstones are what make the
            // deletion travel to the other devices.
            let data = try JSONEncoder().encode(allRecords)
            UserDefaults.standard.set(data, forKey: Self.storageKey())
            updateUpcoming()
            print("💾 SubscriptionManager: Saved \(subscriptions.count) subscriptions (+\(deletedRecords.count) tombstoned)")
            // Cloud mirror (local-first): survive reinstall / cross-device, like transactions.
            if UserManager.shared.currentUser.enableFirebaseSync {
                FirestoreService.shared.saveSubscriptions(data, userId: UserManager.shared.syncUID()) { _ in }
            }
        } catch {
            print("❌ SubscriptionManager: Failed to encode subscriptions - \(error)")
        }
    }

    /// One-time move of the old GLOBAL subscription store into the current user's per-user
    /// key. Non-destructive: the current user adopts the existing subs (so the person who
    /// created them keeps them), a backup copy is kept, and the global key is then removed
    /// so other users/guests don't inherit someone else's subscriptions.
    private func migrateGlobalSubscriptionsIfNeeded() {
        let d = UserDefaults.standard
        let doneFlag = "didMigrateGlobalSubs_v1"
        guard !d.bool(forKey: doneFlag) else { return }
        guard let legacy = d.data(forKey: Self.legacyGlobalKey), !legacy.isEmpty else {
            d.set(true, forKey: doneFlag) // nothing to migrate
            return
        }
        let perUserKey = Self.storageKey()
        if d.data(forKey: perUserKey) == nil {
            d.set(legacy, forKey: perUserKey)
            print("📋 SubscriptionManager: migrated global subs -> \(perUserKey)")
        }
        d.set(legacy, forKey: Self.legacyGlobalKey + "_legacy_backup") // safety copy
        d.removeObject(forKey: Self.legacyGlobalKey) // stop cross-user leak
        d.set(true, forKey: doneFlag)
    }

    // MARK: - CRUD Operations

    func addSubscription(_ subscription: Subscription) {
        var newSubscription = subscription

        // Ensure walletId is set (use current wallet if not provided)
        if newSubscription.walletId == nil {
            newSubscription.walletId = AccountManager.shared.selectedSubAccountId ?? AccountManager.shared.currentSubAccount?.id
            print("📋 SubscriptionManager: Set walletId to \(newSubscription.walletId?.uuidString.prefix(8) ?? "nil")")
        }

        // If auto-add is enabled, create the first transaction immediately at creation time
        if subscription.autoAddTransaction && subscription.isActive {
            // Determine if this subscription's category is income type
            let isIncomeCategory = determineIsIncomeCategory(for: newSubscription)

            // Create first transaction at the subscription's start date (createdAt)
            let firstTransaction = newSubscription.createTransaction(
                accountId: UserManager.shared.currentUser.id,
                forDate: subscription.createdAt,  // Use creation date for first transaction
                isIncomeCategory: isIncomeCategory
            )
            UserManager.shared.addTransaction(firstTransaction)
            print("💰 SubscriptionManager: Created first transaction for '\(subscription.name)' at \(subscription.createdAt), isIncome=\(isIncomeCategory)")

            // Track first transaction generated from subscription
            AnalyticsManager.shared.track(.subscriptionTransactionGenerated, properties: [
                "subscription_name": subscription.name,
                "transaction_amount": firstTransaction.amount,
                "transaction_currency": subscription.currency.rawValue,
                "subscription_frequency": subscription.frequency.rawValue,
                "is_income": isIncomeCategory,
                "is_first_transaction": true
            ])

            // Update subscription state
            newSubscription.lastGeneratedDate = subscription.createdAt
            // nextDueDate should already be set to createdAt + interval by AddSubscriptionSheet
        }

        newSubscription.updatedAt = Date()
        subscriptions.append(newSubscription)
        saveSubscriptions()
        print("➕ SubscriptionManager: Added subscription '\(subscription.name)'")

        // Schedule reminder if enabled
        if subscription.reminderEnabled {
            scheduleReminders()
        }
    }

    func updateSubscription(_ subscription: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            var updated = subscription
            updated.updatedAt = Date()   // loses the LWW race to nothing older — this IS the newest
            subscriptions[index] = updated
            saveSubscriptions()
            print("✏️ SubscriptionManager: Updated subscription '\(subscription.name)'")

            // Reschedule all reminders (handles enabled/disabled changes)
            scheduleReminders()
        }
    }

    func deleteSubscription(_ subscription: Subscription) {
        // Cancel any pending reminder for this subscription
        NotificationManager.shared.cancelSubscriptionReminder(subscriptionId: subscription.id)

        softDelete(ids: [subscription.id])
        print("🗑️ SubscriptionManager: Deleted subscription '\(subscription.name)'")

        // Track deletion event
        AnalyticsManager.shared.track(.subscriptionDeleted, properties: [
            "subscription_name": subscription.name,
            "subscription_amount": subscription.amount,
            "subscription_currency": subscription.currency.rawValue,
            "subscription_frequency": subscription.frequency.rawValue
        ])
    }

    func deleteSubscription(at offsets: IndexSet) {
        softDelete(ids: offsets.map { subscriptions[$0].id })
    }

    /// Move rows to the graveyard with a fresh `updatedAt`, then persist + push. The tombstone is
    /// what the other devices merge; simply dropping the row would let them push it back.
    private func softDelete(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let now = Date()
        for id in ids {
            guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { continue }
            var record = subscriptions.remove(at: index)
            record.isDeleted = true
            record.updatedAt = now
            deletedRecords.insert(record, at: 0)
        }
        if deletedRecords.count > Self.deletedCap {
            deletedRecords = Array(deletedRecords.prefix(Self.deletedCap))
        }
        saveSubscriptions()
    }

    func toggleActive(_ subscription: Subscription) {
        if var sub = subscriptions.first(where: { $0.id == subscription.id }) {
            sub.isActive.toggle()
            sub.updatedAt = Date()
            updateSubscription(sub)
            print("🔄 SubscriptionManager: Toggled '\(sub.name)' to \(sub.isActive ? "active" : "paused")")

            // Track pause/resume event
            AnalyticsManager.shared.track(sub.isActive ? .subscriptionResumed : .subscriptionPaused, properties: [
                "subscription_name": sub.name,
                "subscription_amount": sub.amount,
                "subscription_currency": sub.currency.rawValue,
                "subscription_frequency": sub.frequency.rawValue
            ])
        }
    }

    // MARK: - Upcoming Subscriptions

    private func updateUpcoming() {
        let calendar = Calendar.current
        let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()

        upcomingSubscriptions = subscriptions
            .filter { $0.isActive && $0.nextDueDate <= sevenDaysFromNow }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    // MARK: - Auto-Generation

    /// Check and generate transactions for due subscriptions
    /// Call this on app launch and when app becomes active
    func processSubscriptions() {
        print("🔄 SubscriptionManager: Processing subscriptions...")

        // Migrate subscriptions with nil walletId
        var needsSave = false
        let defaultWalletId = AccountManager.shared.selectedSubAccountId ?? AccountManager.shared.currentSubAccount?.id

        for index in subscriptions.indices {
            if subscriptions[index].walletId == nil {
                subscriptions[index].walletId = defaultWalletId
                subscriptions[index].updatedAt = Date()
                print("📋 SubscriptionManager: Migrated '\(subscriptions[index].name)' walletId to \(subscriptions[index].walletId?.uuidString.prefix(8) ?? "nil")")
                needsSave = true
            }
        }
        if needsSave {
            saveSubscriptions()
        }

        // Also migrate existing transactions with subscriptionId but nil walletID
        if let walletId = defaultWalletId {
            let transactionsToFix = UserManager.shared.currentUser.transactions.filter {
                $0.subscriptionId != nil && $0.walletID == nil
            }
            for txn in transactionsToFix {
                // Create new Txn with fixed walletID (walletID is immutable)
                let fixedTxn = Txn(
                    txID: txn.txID,
                    accountID: txn.accountID,
                    walletID: walletId,
                    category: txn.category,
                    categoryId: txn.categoryId,
                    amount: txn.amount,
                    date: txn.date,
                    createdAt: txn.createdAt,
                    receiptImage: nil,
                    hasReceiptImage: txn.hasReceiptImage,
                    merchantName: txn.merchantName,
                    paymentMethod: txn.paymentMethod,
                    receiptNumber: txn.receiptNumber,
                    invoiceNumber: txn.invoiceNumber,
                    items: txn.items,
                    note: txn.note,
                    originalAmount: txn.originalAmount,
                    originalCurrency: txn.originalCurrency,
                    primaryCurrency: txn.primaryCurrency,
                    secondaryCurrency: txn.secondaryCurrency,
                    exchangeRate: txn.exchangeRate,
                    secondaryAmount: txn.secondaryAmount,
                    secondaryExchangeRate: txn.secondaryExchangeRate,
                    userEnteredAmount: txn.userEnteredAmount,
                    userEnteredCurrency: txn.userEnteredCurrency,
                    subscriptionId: txn.subscriptionId
                )
                UserManager.shared.updateTransaction(fixedTxn)
                print("📋 SubscriptionManager: Fixed transaction walletID for '\(txn.merchantName ?? txn.category)'")
            }
        }

        var generatedCount = 0

        for index in subscriptions.indices {
            var subscription = subscriptions[index]

            // Skip inactive subscriptions
            guard subscription.isActive else { continue }

            // Skip if not set to auto-add
            guard subscription.autoAddTransaction else { continue }

            // Determine if this subscription's category is income type
            let isIncomeCategory = determineIsIncomeCategory(for: subscription)

            // Generate transactions for ALL missed dates (catch-up)
            while subscription.isDue {
                // Signing in (or connecting a box) brings the account's already-generated
                // occurrences down from the cloud, but this subscription's own bookkeeping may
                // still say the date is unpaid — generating a second copy of a transaction the
                // user already has. Skip the create and just advance the schedule.
                if UserManager.shared.hasGeneratedOccurrence(
                    sourceId: subscription.id,
                    due: subscription.nextDueDate
                ) {
                    print("↩️ SubscriptionManager: '\(subscription.name)' occurrence \(subscription.nextDueDate) already exists — advancing without generating")
                    subscription.markAsGenerated()
                    continue
                }

                // Create transaction with the due date and correct amount sign
                let transaction = subscription.createTransaction(
                    accountId: UserManager.shared.currentUser.id,
                    isIncomeCategory: isIncomeCategory
                )

                // Add to user's transactions
                UserManager.shared.addTransaction(transaction)

                // Track auto-generated transaction event
                AnalyticsManager.shared.track(.subscriptionTransactionGenerated, properties: [
                    "subscription_name": subscription.name,
                    "transaction_amount": transaction.amount,
                    "transaction_currency": subscription.currency.rawValue,
                    "subscription_frequency": subscription.frequency.rawValue,
                    "is_income": isIncomeCategory
                ])

                // Update subscription - advances nextDueDate
                subscription.markAsGenerated()
                generatedCount += 1

                print("✅ SubscriptionManager: Generated transaction for '\(subscription.name)' - Due: \(subscription.nextDueDate), isIncome: \(isIncomeCategory)")
            }

            // Update in array
            subscription.updatedAt = Date()
            subscriptions[index] = subscription
        }

        if generatedCount > 0 {
            saveSubscriptions()
            print("📊 SubscriptionManager: Generated \(generatedCount) transactions")
        } else {
            print("📊 SubscriptionManager: No transactions to generate")
        }

        updateUpcoming()
    }

    /// Determine if a subscription's category is income type
    private func determineIsIncomeCategory(for subscription: Subscription) -> Bool {
        let categoriesManager = CategoriesManager.shared

        // Try to find by categoryId first (handles both categories and subcategories)
        if let catId = subscription.categoryId {
            if let result = categoriesManager.findCategoryOrSubcategoryById(catId) {
                if let category = result.category {
                    return category.type == .income
                } else if let subcategory = result.subcategory {
                    return subcategory.type == .income
                }
            }
        }

        // Fallback to name lookup
        let result = categoriesManager.findCategoryOrSubcategory(by: subscription.category)
        if let cat = result.category {
            return cat.type == .income
        } else if let subcat = result.subcategory {
            return subcat.type == .income
        }

        // Default to expense if category not found
        return false
    }

    // MARK: - Reminders

    /// Schedule reminders for all subscriptions with reminders enabled
    func scheduleReminders() {
        print("🔔 SubscriptionManager: Scheduling subscription reminders...")
        print("🔔 SubscriptionManager: Total subscriptions: \(subscriptions.count)")

        // First cancel all existing subscription reminders to avoid duplicates
        NotificationManager.shared.cancelAllSubscriptionReminders()

        // Debug: List all subscriptions and their reminder status
        for sub in subscriptions {
            print("🔔   - '\(sub.name)': active=\(sub.isActive), reminderEnabled=\(sub.reminderEnabled), reminderDaysBefore=\(sub.reminderDaysBefore), nextDue=\(sub.nextDueDate)")
        }

        // Schedule reminders for subscriptions with reminders enabled
        let subscriptionsWithReminders = subscriptions.filter { $0.isActive && $0.reminderEnabled }

        for subscription in subscriptionsWithReminders {
            // Get the reminder interval from ReminderDays enum
            let reminderDays = ReminderDays(rawValue: subscription.reminderDaysBefore) ?? .one
            let reminderInterval = reminderDays.timeIntervalBeforeDue

            // Determine if this subscription's category is income type
            let isIncome = determineIsIncomeCategory(for: subscription)

            print("🔔 SubscriptionManager: Scheduling '\(subscription.name)' - interval=\(reminderInterval)s, nextDue=\(subscription.nextDueDate), isIncome=\(isIncome)")

            NotificationManager.shared.scheduleSubscriptionReminder(
                subscriptionId: subscription.id,
                subscriptionName: subscription.name,
                dueDate: subscription.nextDueDate,
                reminderInterval: reminderInterval,
                isIncome: isIncome
            )
        }

        print("🔔 SubscriptionManager: Scheduled \(subscriptionsWithReminders.count) subscription reminders")

        // Debug: List all pending notifications
        NotificationManager.shared.listPendingNotifications()
    }

    // MARK: - Statistics

    /// Total monthly spend converted to user's primary currency
    var totalMonthlySpend: Double {
        let primaryCurrency = CurrencyPreferences.shared.primaryCurrency
        return subscriptions
            .filter { $0.isActive }
            .reduce(0) { total, subscription in
                // Convert each subscription's monthly cost to primary currency
                let convertedAmount = CurrencyRateManager.shared.convertAmount(
                    subscription.monthlyCost,
                    from: subscription.currency,
                    to: primaryCurrency
                )
                return total + convertedAmount
            }
    }

    /// Total annual spend converted to user's primary currency
    var totalAnnualSpend: Double {
        let primaryCurrency = CurrencyPreferences.shared.primaryCurrency
        return subscriptions
            .filter { $0.isActive }
            .reduce(0) { total, subscription in
                // Convert each subscription's annual cost to primary currency
                let convertedAmount = CurrencyRateManager.shared.convertAmount(
                    subscription.annualCost,
                    from: subscription.currency,
                    to: primaryCurrency
                )
                return total + convertedAmount
            }
    }

    var activeCount: Int {
        subscriptions.filter { $0.isActive }.count
    }

    // MARK: - Auto Refresh

    private func setupAutoRefresh() {
        // Process subscriptions and refresh every 30 seconds (for minute-frequency testing)
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processSubscriptions()
            }
            .store(in: &cancellables)

        // Reload the per-user subscription list whenever the active user changes
        // (login, guest switch, cloud restore) so subs stay scoped to the current user.
        NotificationCenter.default.publisher(for: NSNotification.Name("UserManagerFirebaseLoadComplete"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadForCurrentUser()
            }
            .store(in: &cancellables)
    }

    // MARK: - App Lifecycle

    /// Call when app launches or becomes active
    func onAppActive() {
        processSubscriptions()
        scheduleReminders()
    }

    // MARK: - Debug

    func loadSampleData() {
        subscriptions = Subscription.samples
        deletedRecords = []
        saveSubscriptions()
        print("🧪 SubscriptionManager: Loaded sample data")
    }

    func clearAllSubscriptions() {
        // Cancel all notifications first
        NotificationManager.shared.cancelAllSubscriptionReminders()

        // Deliberately NOT tombstoned: this is a local reset / account-deletion path, and the
        // cloud copy is removed separately. Writing 300 tombstones to a doc being deleted is noise.
        subscriptions = []
        deletedRecords = []
        saveSubscriptions()
        print("🧹 SubscriptionManager: Cleared all subscriptions")
    }

    /// Reset all subscriptions' nextDueDate to the next FUTURE occurrence from NOW
    /// Call this after deleting transactions to prevent catch-up from recreating them
    func resetAllDueDates() {
        let now = Date()
        var resetCount = 0

        for index in subscriptions.indices {
            var subscription = subscriptions[index]

            // If nextDueDate is in the past, calculate next due from NOW (not from old date)
            if subscription.nextDueDate <= now {
                // Calculate next due date starting from NOW, not the old stale date
                let nextDate = subscription.calculateNextDueDate(after: now)
                subscription.nextDueDate = nextDate
                subscription.lastGeneratedDate = nil  // Clear last generated
                subscription.updatedAt = Date()
                subscriptions[index] = subscription
                resetCount += 1
                print("📅 SubscriptionManager: Reset '\(subscription.name)' nextDueDate to \(nextDate)")
            }
        }

        if resetCount > 0 {
            saveSubscriptions()
            print("📅 SubscriptionManager: Reset \(resetCount) subscription due dates to future")
        } else {
            print("📅 SubscriptionManager: All subscriptions already have future due dates")
        }
    }
}
