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
    static let freeSubscriptionLimit = 2

    /// Check if user can add more subscriptions (Pro users unlimited, free users limited to 2)
    var canAddMoreSubscriptions: Bool {
        if RevenueCatManager.shared.isProUser {
            return true
        }
        return subscriptions.count < Self.freeSubscriptionLimit
    }

    /// Number of remaining free subscription slots
    var remainingFreeSlots: Int {
        if RevenueCatManager.shared.isProUser {
            return Int.max
        }
        return max(0, Self.freeSubscriptionLimit - subscriptions.count)
    }

    // MARK: - Private Properties

    private let storageKey = "cashmonki_subscriptions"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadSubscriptions()
        setupAutoRefresh()
    }

    // MARK: - Storage

    private func loadSubscriptions() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let decoded = try JSONDecoder().decode([Subscription].self, from: data)
                subscriptions = decoded
                updateUpcoming()
                print("📋 SubscriptionManager: Loaded \(decoded.count) subscriptions")
            } catch {
                print("❌ SubscriptionManager: Failed to decode subscriptions - \(error)")
                subscriptions = []
            }
        }
    }

    private func saveSubscriptions() {
        do {
            let data = try JSONEncoder().encode(subscriptions)
            UserDefaults.standard.set(data, forKey: storageKey)
            updateUpcoming()
            print("💾 SubscriptionManager: Saved \(subscriptions.count) subscriptions")
        } catch {
            print("❌ SubscriptionManager: Failed to encode subscriptions - \(error)")
        }
    }

    // MARK: - CRUD Operations

    func addSubscription(_ subscription: Subscription) {
        var newSubscription = subscription

        // If auto-add is enabled, create the first transaction immediately at creation time
        if subscription.autoAddTransaction && subscription.isActive {
            // Create first transaction at the subscription's start date (createdAt)
            let firstTransaction = newSubscription.createTransaction(
                accountId: UserManager.shared.currentUser.id,
                forDate: subscription.createdAt  // Use creation date for first transaction
            )
            UserManager.shared.addTransaction(firstTransaction)
            print("💰 SubscriptionManager: Created first transaction for '\(subscription.name)' at \(subscription.createdAt)")

            // Update subscription state
            newSubscription.lastGeneratedDate = subscription.createdAt
            // nextDueDate should already be set to createdAt + interval by AddSubscriptionSheet
        }

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
            subscriptions[index] = subscription
            saveSubscriptions()
            print("✏️ SubscriptionManager: Updated subscription '\(subscription.name)'")

            // Reschedule all reminders (handles enabled/disabled changes)
            scheduleReminders()
        }
    }

    func deleteSubscription(_ subscription: Subscription) {
        // Cancel any pending reminder for this subscription
        NotificationManager.shared.cancelSubscriptionReminder(subscriptionId: subscription.id)

        subscriptions.removeAll { $0.id == subscription.id }
        saveSubscriptions()
        print("🗑️ SubscriptionManager: Deleted subscription '\(subscription.name)'")
    }

    func deleteSubscription(at offsets: IndexSet) {
        subscriptions.remove(atOffsets: offsets)
        saveSubscriptions()
    }

    func toggleActive(_ subscription: Subscription) {
        if var sub = subscriptions.first(where: { $0.id == subscription.id }) {
            sub.isActive.toggle()
            updateSubscription(sub)
            print("🔄 SubscriptionManager: Toggled '\(sub.name)' to \(sub.isActive ? "active" : "paused")")
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
                // Create transaction with the due date and correct amount sign
                let transaction = subscription.createTransaction(
                    accountId: UserManager.shared.currentUser.id,
                    isIncomeCategory: isIncomeCategory
                )

                // Add to user's transactions
                UserManager.shared.addTransaction(transaction)

                // Update subscription - advances nextDueDate
                subscription.markAsGenerated()
                generatedCount += 1

                print("✅ SubscriptionManager: Generated transaction for '\(subscription.name)' - Due: \(subscription.nextDueDate), isIncome: \(isIncomeCategory)")
            }

            // Update in array
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

            print("🔔 SubscriptionManager: Scheduling '\(subscription.name)' - interval=\(reminderInterval)s, nextDue=\(subscription.nextDueDate)")

            NotificationManager.shared.scheduleSubscriptionReminder(
                subscriptionId: subscription.id,
                subscriptionName: subscription.name,
                dueDate: subscription.nextDueDate,
                reminderInterval: reminderInterval
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
        saveSubscriptions()
        print("🧪 SubscriptionManager: Loaded sample data")
    }

    func clearAllSubscriptions() {
        // Cancel all notifications first
        NotificationManager.shared.cancelAllSubscriptionReminders()

        subscriptions = []
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
