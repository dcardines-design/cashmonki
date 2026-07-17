//
//  RecurringTimelineSection.swift
//  CashMonki
//
//  Displays a timeline of recurring transaction occurrences
//

import SwiftUI

struct RecurringTimelineSection: View {
    let transaction: Txn
    let onTransactionTap: ((Txn) -> Void)?
    @ObservedObject private var recurringManager = RecurringTransactionManager.shared
    @ObservedObject private var userManager = UserManager.shared

    init(transaction: Txn, onTransactionTap: ((Txn) -> Void)? = nil) {
        self.transaction = transaction
        self.onTransactionTap = onTransactionTap
    }

    // Date formatter for timeline entries
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    /// Get the template for this transaction (either itself or parent)
    private var template: Txn? {
        if recurringManager.isTemplate(transaction) {
            return transaction
        } else if let templateId = transaction.recurringTemplateId {
            return recurringManager.getParentTemplate(for: transaction.id)
        }
        return nil
    }

    /// Check if this section should be displayed
    var shouldDisplay: Bool {
        let isTemplate = recurringManager.isTemplate(transaction)
        let isChild = recurringManager.isGeneratedChild(transaction)
        print("🔄 RecurringTimelineSection.shouldDisplay:")
        print("   - Transaction: \(transaction.merchantName ?? transaction.category)")
        print("   - isRecurring: \(transaction.isRecurring)")
        print("   - recurringTemplateId: \(transaction.recurringTemplateId?.uuidString.prefix(8) ?? "nil")")
        print("   - isTemplate: \(isTemplate)")
        print("   - isGeneratedChild: \(isChild)")
        print("   - shouldDisplay: \(isTemplate || isChild)")
        return isTemplate || isChild
    }

    /// Get all timeline entries sorted by date
    private var timelineEntries: [TimelineEntry] {
        guard let template = template else { return [] }

        var entries: [TimelineEntry] = []

        // Add template as first entry
        // Use secondaryAmount if available, otherwise fall back to originalAmount
        let templateSecondaryAmount = template.secondaryAmount ?? template.originalAmount
        let templateSecondaryCurrency = template.secondaryCurrency ?? template.originalCurrency

        entries.append(TimelineEntry(
            id: template.id,
            merchantName: template.merchantName ?? template.category,
            date: template.date,
            primaryAmount: template.amount,
            primaryCurrency: template.primaryCurrency,
            secondaryAmount: templateSecondaryAmount,
            secondaryCurrency: templateSecondaryCurrency,
            type: .started,
            isCurrentTransaction: template.id == transaction.id
        ))

        // Add all generated children
        let children = recurringManager.getGeneratedTransactions(for: template.id)
        for child in children {
            // Use secondaryAmount if available, otherwise fall back to originalAmount
            let childSecondaryAmount = child.secondaryAmount ?? child.originalAmount
            let childSecondaryCurrency = child.secondaryCurrency ?? child.originalCurrency

            entries.append(TimelineEntry(
                id: child.id,
                merchantName: child.merchantName ?? child.category,
                date: child.date,
                primaryAmount: child.amount,
                primaryCurrency: child.primaryCurrency,
                secondaryAmount: childSecondaryAmount,
                secondaryCurrency: childSecondaryCurrency,
                type: .renewed,
                isCurrentTransaction: child.id == transaction.id
            ))
        }

        // Sort by date
        entries.sort { $0.date < $1.date }

        // Add next renewal prediction if template is active
        if template.isRecurringActive, let frequency = template.recurringFrequency {
            let lastDate = entries.last?.date ?? template.date
            let nextDate = frequency.nextOccurrence(from: lastDate)

            // Only show if next date is in the future
            if nextDate > Date() {
                entries.append(TimelineEntry(
                    id: UUID(), // Placeholder ID for prediction
                    merchantName: template.merchantName ?? template.category,
                    date: nextDate,
                    primaryAmount: template.amount,
                    primaryCurrency: template.primaryCurrency,
                    secondaryAmount: templateSecondaryAmount,
                    secondaryCurrency: templateSecondaryCurrency,
                    type: .nextRenewal,
                    isCurrentTransaction: false
                ))
            }
        }

        return entries
    }

    /// Get display name for frequency
    private var frequencyDisplayName: String {
        guard let template = template,
              let frequency = template.recurringFrequency else {
            return "Recurring"
        }

        switch frequency {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Every Month"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Text("Repeats")
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundSecondary)

                Spacer()

                Text(frequencyDisplayName)
                    .font(AppFonts.overusedGroteskMedium(size: 16))
                    .foregroundColor(AppColors.foregroundPrimary)
            }

            // Timeline card
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(timelineEntries.enumerated()), id: \.element.id) { index, entry in
                    TimelineEntryRow(
                        entry: entry,
                        dateFormatter: dateFormatter,
                        frequency: template?.recurringFrequency,
                        isFirst: index == 0,
                        isLast: index == timelineEntries.count - 1,
                        onTap: {
                            // Don't do anything for next renewal (it's a prediction, not a real transaction)
                            guard entry.type != .nextRenewal else { return }

                            // Find the full transaction and call the callback
                            if let fullTransaction = userManager.currentUser.transactions.first(where: { $0.id == entry.id }) {
                                onTransactionTap?(fullTransaction)
                            }
                        }
                    )
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(AppColors.surfacePrimary)
            .cornerRadius(18)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Timeline Entry Model

private struct TimelineEntry: Identifiable {
    let id: UUID
    let merchantName: String
    let date: Date
    let primaryAmount: Double
    let primaryCurrency: Currency
    let secondaryAmount: Double?
    let secondaryCurrency: Currency?
    let type: EntryType
    let isCurrentTransaction: Bool

    enum EntryType {
        case started
        case renewed
        case nextRenewal
    }
}

// MARK: - Timeline Entry Row

private struct TimelineEntryRow: View {
    let entry: TimelineEntry
    let dateFormatter: DateFormatter
    let frequency: RecurringFrequency?
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void

    /// Date formatter that includes time (for minute frequency)
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter
    }

    /// Format currency amount with smart decimals
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: abs(amount))) ?? String(format: "%.0f", abs(amount))
    }

    /// Get formatted date string
    private func formattedDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    /// Get subtitle text based on entry type
    private var subtitleText: String {
        switch entry.type {
        case .started:
            return "Started \(formattedDate(entry.date))"
        case .renewed:
            return "Renewed \(formattedDate(entry.date))"
        case .nextRenewal:
            return "Next renewal on \(formattedDate(entry.date))"
        }
    }

    /// Whether this entry is faded (future prediction)
    private var isFaded: Bool {
        entry.type == .nextRenewal
    }

    /// Primary text color
    private var primaryTextColor: Color {
        if isFaded {
            return AppColors.foregroundTertiary
        }
        return AppColors.foregroundPrimary
    }

    /// Secondary text color
    private var secondaryTextColor: Color {
        if isFaded {
            return AppColors.foregroundTertiary
        }
        return AppColors.foregroundSecondary
    }

    /// Amount color (red for expenses, green for income)
    private var amountColor: Color {
        if isFaded {
            return AppColors.foregroundTertiary
        }
        return entry.primaryAmount < 0 ? AppColors.accentRed : AppColors.accentGreen
    }

    var body: some View {
        HStack(alignment: .center, spacing: entry.isCurrentTransaction ? 4 : 12) {
            // Left side - Merchant and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.merchantName)
                    .font(AppFonts.overusedGroteskMedium(size: 18))
                    .foregroundColor(primaryTextColor)

                Text(subtitleText)
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundColor(secondaryTextColor)
            }

            Spacer()

            // Right side - Amounts
            VStack(alignment: .trailing, spacing: 2) {
                // Primary amount
                Text("\(entry.primaryCurrency.symbol)\(formatAmount(entry.primaryAmount))")
                    .font(AppFonts.overusedGroteskMedium(size: 20))
                    .foregroundColor(amountColor)

                // Secondary amount (if available)
                if let secondaryAmount = entry.secondaryAmount,
                   let secondaryCurrency = entry.secondaryCurrency {
                    Text("\(secondaryCurrency.symbol)\(formatAmount(secondaryAmount))")
                        .font(AppFonts.overusedGroteskMedium(size: 14))
                        .foregroundColor(secondaryTextColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, entry.isCurrentTransaction ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundWhite)
        .cornerRadius(10)
        .overlay(
            Group {
                if entry.isCurrentTransaction {
                    RoundedRectangle(cornerRadius: 10)
                        .inset(by: 0.5)
                        .stroke(AppColors.accentBackground, lineWidth: 1)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    /// Determine which corners should be rounded
    private var cornerMask: UIRectCorner {
        if isFirst && isLast {
            return .allCorners
        } else if isFirst {
            return [.topLeft, .topRight]
        } else if isLast {
            return [.bottomLeft, .bottomRight]
        } else {
            return []
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        RecurringTimelineSection(
            transaction: Txn(
                txID: UUID(),
                accountID: UUID(),
                walletID: UUID(),
                category: "Subscriptions",
                categoryId: nil,
                amount: -175,
                date: Date(),
                createdAt: Date(),
                receiptImage: nil,
                hasReceiptImage: false,
                merchantName: "Netflix",
                paymentMethod: nil,
                receiptNumber: nil,
                invoiceNumber: nil,
                items: [],
                note: nil,
                originalAmount: nil,
                originalCurrency: nil,
                primaryCurrency: .php,
                secondaryCurrency: .usd,
                exchangeRate: nil,
                secondaryAmount: 10.09,
                secondaryExchangeRate: nil,
                isRecurring: true,
                recurringFrequency: .monthly,
                recurringTemplateId: nil,
                lastGeneratedDate: nil,
                isRecurringActive: true
            )
        )
    }
    .padding(.vertical, 20)
    .background(AppColors.backgroundWhite)
}
