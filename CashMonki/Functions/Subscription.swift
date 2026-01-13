//
//  Subscription.swift
//  CashMonki
//
//  Model for recurring payments/subscriptions
//

import Foundation

// MARK: - Subscription Model

struct Subscription: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String                          // e.g., "Netflix", "Spotify"
    var amount: Double                        // Payment amount
    var currency: Currency                    // Payment currency
    var categoryId: UUID?                     // Category for generated transactions
    var category: String                      // Category name for display
    var frequency: RecurringFrequency         // How often it repeats
    var nextDueDate: Date                     // When the next charge is due
    var reminderEnabled: Bool                 // Whether to send reminder
    var reminderDaysBefore: Int               // Days before to remind (1, 3, 5)
    var autoAddTransaction: Bool              // Auto-create transaction when due
    var isActive: Bool                        // Pause/resume subscription tracking
    var walletId: UUID?                       // Which wallet this belongs to
    var note: String?                         // Optional notes
    var createdAt: Date                       // When subscription was created
    var lastGeneratedDate: Date?              // Last time a transaction was generated

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        currency: Currency,
        categoryId: UUID? = nil,
        category: String,
        frequency: RecurringFrequency,
        nextDueDate: Date,
        reminderEnabled: Bool = false,
        reminderDaysBefore: Int = 1,
        autoAddTransaction: Bool = true,
        isActive: Bool = true,
        walletId: UUID? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        lastGeneratedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currency = currency
        self.categoryId = categoryId
        self.category = category
        self.frequency = frequency
        self.nextDueDate = nextDueDate
        self.reminderEnabled = reminderEnabled
        self.reminderDaysBefore = reminderDaysBefore
        self.autoAddTransaction = autoAddTransaction
        self.isActive = isActive
        self.walletId = walletId
        self.note = note
        self.createdAt = createdAt
        self.lastGeneratedDate = lastGeneratedDate
    }

    // MARK: - Computed Properties

    /// Calculate the next due date after a given date
    func calculateNextDueDate(after date: Date = Date()) -> Date {
        let calendar = Calendar.current

        switch frequency {
        case .fiveMinutes:
            return calendar.date(byAdding: .minute, value: 5, to: date) ?? date
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }

    /// Check if the subscription is due (nextDueDate is NOW or in the past)
    /// For minute-frequency precision, we check exact time, not just "today"
    var isDue: Bool {
        return nextDueDate <= Date()
    }

    /// Days until next charge
    var daysUntilDue: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: nextDueDate)
        return max(0, components.day ?? 0)
    }

    /// Minutes until next charge (for minute-frequency precision)
    var minutesUntilDue: Int {
        let seconds = nextDueDate.timeIntervalSince(Date())
        return max(0, Int(seconds / 60))
    }

    /// Seconds until next charge (for testing precision)
    var secondsUntilDue: Int {
        let seconds = nextDueDate.timeIntervalSince(Date())
        return max(0, Int(seconds))
    }

    /// Human-readable due date text (with minute precision for 5-minute frequency)
    var dueText: String {
        // For 5-minute frequency, show precise time
        if frequency == .fiveMinutes {
            let seconds = secondsUntilDue
            if seconds <= 0 {
                return "Due now"
            } else if seconds < 60 {
                return "Due in \(seconds)s"
            } else {
                let minutes = minutesUntilDue
                return "Due in \(minutes)m"
            }
        }

        // For other frequencies, show days
        let days = daysUntilDue
        if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else if days <= 7 {
            return "Due in \(days) days"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Due \(formatter.string(from: nextDueDate))"
        }
    }

    /// Check if reminder should be sent today
    var shouldRemindToday: Bool {
        guard reminderEnabled else { return false }
        return daysUntilDue == reminderDaysBefore
    }

    /// Annual cost calculation
    var annualCost: Double {
        switch frequency {
        case .fiveMinutes:
            return amount * 12 * 24 * 365 // For testing (12 times per hour)
        case .daily:
            return amount * 365
        case .weekly:
            return amount * 52
        case .monthly:
            return amount * 12
        case .quarterly:
            return amount * 4
        case .yearly:
            return amount
        }
    }

    /// Monthly cost calculation (approximate)
    var monthlyCost: Double {
        return annualCost / 12
    }
}

// MARK: - Subscription Extensions

extension Subscription {
    /// Create a transaction from this subscription
    /// - Parameters:
    ///   - accountId: The account ID for the transaction
    ///   - forDate: Optional date for the transaction (defaults to nextDueDate)
    ///   - isIncomeCategory: Whether this subscription's category is income type (determines amount sign)
    func createTransaction(accountId: UUID, forDate: Date? = nil, isIncomeCategory: Bool = false) -> Txn {
        let transactionDate = forDate ?? nextDueDate

        // Amount sign based on category type (income = positive, expense = negative)
        let finalAmount = isIncomeCategory ? abs(amount) : -abs(amount)

        return Txn(
            txID: UUID(),
            accountID: accountId,
            walletID: walletId,
            category: category,
            categoryId: categoryId,
            amount: finalAmount,
            date: transactionDate,
            createdAt: Date(),
            receiptImage: nil,
            hasReceiptImage: false,
            merchantName: name,
            paymentMethod: nil,
            receiptNumber: nil,
            invoiceNumber: nil,
            items: [],
            note: note ?? "Auto-generated from subscription",
            originalAmount: amount,
            originalCurrency: currency,
            primaryCurrency: currency,
            secondaryCurrency: nil,
            exchangeRate: 1.0,
            secondaryAmount: nil,
            secondaryExchangeRate: nil,
            userEnteredAmount: amount,
            userEnteredCurrency: currency,
            subscriptionId: id // Link back to this subscription
        )
    }

    /// Update subscription after generating a transaction
    mutating func markAsGenerated() {
        lastGeneratedDate = nextDueDate
        nextDueDate = calculateNextDueDate(after: nextDueDate)
    }
}

// MARK: - Sample Data

extension Subscription {
    static let samples: [Subscription] = [
        Subscription(
            name: "Netflix",
            amount: 549,
            currency: .php,
            category: "Entertainment",
            frequency: .monthly,
            nextDueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            reminderEnabled: true,
            reminderDaysBefore: 3
        ),
        Subscription(
            name: "Spotify",
            amount: 149,
            currency: .php,
            category: "Entertainment",
            frequency: .monthly,
            nextDueDate: Calendar.current.date(byAdding: .day, value: 12, to: Date())!,
            reminderEnabled: true,
            reminderDaysBefore: 1
        ),
        Subscription(
            name: "iCloud Storage",
            amount: 49,
            currency: .php,
            category: "Utilities",
            frequency: .monthly,
            nextDueDate: Calendar.current.date(byAdding: .day, value: 20, to: Date())!,
            reminderEnabled: false
        )
    ]
}
