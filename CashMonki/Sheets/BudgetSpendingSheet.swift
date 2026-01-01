//
//  BudgetSpendingSheet.swift
//  CashMonki
//
//  Shows transactions for a specific budget category
//

import SwiftUI

struct BudgetSpendingSheet: View {
    @Binding var isPresented: Bool
    let budget: Budget
    let displayPeriod: BudgetPeriod
    let selectedDate: Date

    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var budgetManager = BudgetManager.shared
    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared
    @EnvironmentObject var toastManager: ToastManager

    @State private var selectedTransactionForDetail: Txn?
    @State private var showingBudgetMenu: Bool = false
    @State private var showingEditBudget: Bool = false

    // MARK: - Computed Properties

    /// Get transactions for this budget in the selected period
    private var budgetTransactions: [Txn] {
        let periodRange = budgetManager.periodRange(for: displayPeriod, containing: selectedDate)
        return budgetManager.getTransactionsForBudget(budget, in: periodRange)
            .sorted { $0.date > $1.date }
    }

    /// Group transactions by day
    private var groupedTransactions: [(String, [Txn])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: budgetTransactions) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            let title: String
            if calendar.isDateInToday(day) {
                title = "Today"
            } else if calendar.isDateInYesterday(day) {
                title = "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d, yyyy"
                title = formatter.string(from: day)
            }
            return (title, groups[day]!.sorted { $0.createdAt > $1.createdAt })
        }
    }

    /// Spent amount for display
    private var spentAmount: Double {
        budgetManager.spentAmount(for: budget, displayPeriod: displayPeriod, on: selectedDate)
    }

    /// Budget amount adjusted for display period
    private var periodAdjustedBudgetAmount: Double {
        if displayPeriod == budget.period {
            return budget.amount
        }
        return budgetManager.convertAmount(budget.amount, from: budget.period, to: displayPeriod)
    }

    /// Converted to primary currency
    private var convertedBudgetAmount: Double {
        let primaryCurrency = currencyPrefs.primaryCurrency
        if budget.currency == primaryCurrency {
            return periodAdjustedBudgetAmount
        }
        return CurrencyRateManager.shared.convertAmount(periodAdjustedBudgetAmount, from: budget.currency, to: primaryCurrency)
    }

    private var convertedSpentAmount: Double {
        let primaryCurrency = currencyPrefs.primaryCurrency
        if budget.currency == primaryCurrency {
            return spentAmount
        }
        return CurrencyRateManager.shared.convertAmount(spentAmount, from: budget.currency, to: primaryCurrency)
    }

    private var remainingAmount: Double {
        convertedBudgetAmount - convertedSpentAmount
    }

    private var isOverBudget: Bool {
        convertedSpentAmount > convertedBudgetAmount
    }

    private var progress: Double {
        guard convertedBudgetAmount > 0 else { return 0 }
        return min(convertedSpentAmount / convertedBudgetAmount, 1.0)
    }

    private var progressBarColor: Color {
        let percentUsed = convertedBudgetAmount > 0 ? convertedSpentAmount / convertedBudgetAmount : 0
        if percentUsed > 1.0 {
            return AppColors.destructiveForeground
        }
        if percentUsed >= 0.75 {
            return Color(hex: "FF9E15") ?? AppColors.accentOrange
        }
        if percentUsed >= 0.5 {
            return Color(hex: "FFCC00") ?? .yellow
        }
        return AppColors.successForeground
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with surface color background
            SheetHeader.withCustomBackground(
                title: "Budgets Spending",
                onBackTap: { isPresented = false },
                backgroundColor: AppColors.surfacePrimary
            )

            // Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Budget card at top
                    budgetCardSection

                    // Transactions grouped by date
                    transactionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .background(AppColors.surfacePrimary)
        }
        .background(AppColors.surfacePrimary)
        .sheet(item: $selectedTransactionForDetail) { transaction in
            ReceiptDetailSheet(
                transaction: transaction,
                onTransactionUpdate: { updatedTransaction in
                    userManager.updateTransaction(updatedTransaction)
                },
                onTransactionDelete: { deletedTransaction in
                    userManager.removeTransaction(withId: deletedTransaction.id)
                    selectedTransactionForDetail = nil
                    toastManager.showDeleted("Transaction deleted")
                },
                onDismiss: {
                    selectedTransactionForDetail = nil
                }
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
        }
        .confirmationDialog(
            "Budget Options",
            isPresented: $showingBudgetMenu
        ) {
            Button("Edit Budget") {
                showingEditBudget = true
            }
            Button("Delete Budget", role: .destructive) {
                userManager.deleteBudget(budget)
                toastManager.showDeleted("Budget deleted")
                isPresented = false
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingEditBudget) {
            EditBudgetSheet(
                isPresented: $showingEditBudget,
                budget: budget,
                onSave: { updatedBudget in
                    userManager.updateBudget(updatedBudget)
                    toastManager.showSuccess("Budget updated!")
                },
                onDelete: {
                    userManager.deleteBudget(budget)
                    toastManager.showDeleted("Budget deleted")
                    isPresented = false
                }
            )
            .presentationDetents([.fraction(0.98)])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Budget Card Section

    private var budgetCardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Row 1: Category + Menu icon
            HStack(spacing: 12) {
                // Emoji in circle
                Text(TxnCategoryIcon.emojiFor(category: budget.categoryName))
                    .font(.system(size: 18))
                    .frame(width: 34, height: 34)
                    .background(AppColors.surfacePrimary)
                    .clipShape(Circle())

                // Category name
                Text(budget.categoryName)
                    .font(AppFonts.overusedGroteskMedium(size: 18))
                    .foregroundStyle(AppColors.foregroundPrimary)

                Spacer()

                // Three-dot menu button
                Button(action: { showingBudgetMenu = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.foregroundTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Row 2: Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.linePrimary)
                        .frame(height: 8)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressBarColor)
                        .frame(width: max(0, geometry.size.width * progress), height: 8)
                }
            }
            .frame(height: 8)

            // Row 3: Amounts + Status
            HStack {
                // Spent / Budget
                HStack(spacing: 4) {
                    Text(currencyPrefs.formatPrimaryAmount(convertedSpentAmount))
                        .font(AppFonts.overusedGroteskSemiBold(size: 18))
                        .foregroundStyle(AppColors.foregroundPrimary)

                    Text("/")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundStyle(AppColors.foregroundTertiary)

                    Text(currencyPrefs.formatPrimaryAmount(convertedBudgetAmount))
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundStyle(AppColors.foregroundTertiary)
                }

                Spacer()

                // Status text
                if isOverBudget {
                    Text("\(currencyPrefs.formatPrimaryAmount(abs(remainingAmount))) over budget")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundStyle(AppColors.destructiveForeground)
                } else {
                    Text("\(currencyPrefs.formatPrimaryAmount(remainingAmount)) left")
                        .font(AppFonts.overusedGroteskMedium(size: 16))
                        .foregroundStyle(AppColors.foregroundTertiary)
                }
            }
        }
        .padding(16)
        .background(AppColors.backgroundWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Transactions Section

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(Array(groupedTransactions.enumerated()), id: \.offset) { _, section in
                let dailyTotal = section.1.reduce(0) { $0 + $1.amount }

                VStack(alignment: .leading, spacing: 10) {
                    // Date header with daily total
                    HStack {
                        Text(section.0)
                            .font(AppFonts.overusedGroteskMedium(size: 14))
                            .foregroundStyle(AppColors.foregroundSecondary)

                        Spacer()

                        Text(currencyPrefs.formatPrimaryAmount(dailyTotal))
                            .font(AppFonts.overusedGroteskMedium(size: 16))
                            .foregroundStyle(AppColors.foregroundSecondary)
                    }

                    // Transaction rows
                    VStack(spacing: 0) {
                        ForEach(Array(section.1.enumerated()), id: \.element.id) { index, txn in
                            UnifiedTransactionDisplay.row(
                                transaction: txn,
                                onTap: {
                                    selectedTransactionForDetail = txn
                                },
                                onTransactionUpdate: { updatedTransaction in
                                    userManager.updateTransaction(updatedTransaction)
                                }
                            )

                            if index < section.1.count - 1 {
                                Divider()
                                    .padding(.leading, 64)
                            }
                        }
                    }
                    .background(AppColors.backgroundWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

}

// MARK: - Preview

#Preview {
    BudgetSpendingSheet(
        isPresented: .constant(true),
        budget: Budget(
            walletId: UUID(),
            categoryId: UUID(),
            categoryName: "Coffee",
            amount: 5000,
            currency: .php,
            period: .monthly
        ),
        displayPeriod: .monthly,
        selectedDate: Date()
    )
    .environmentObject(ToastManager())
}
