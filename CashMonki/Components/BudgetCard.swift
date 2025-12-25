//
//  BudgetCard.swift
//  CashMonki
//
//  Created by Claude on 12/24/25.
//

import SwiftUI

struct BudgetCard: View {
    let budget: Budget
    let spentAmount: Double
    let displayPeriod: BudgetPeriod?  // If set, shows equivalent amount for this period
    let onMenuTap: () -> Void

    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared
    private let rateManager = CurrencyRateManager.shared
    private let budgetManager = BudgetManager.shared

    // MARK: - Period Conversion

    /// The budget amount adjusted for display period (if different from original)
    private var periodAdjustedBudgetAmount: Double {
        guard let displayPeriod = displayPeriod, displayPeriod != budget.period else {
            return budget.amount
        }
        return budgetManager.convertAmount(budget.amount, from: budget.period, to: displayPeriod)
    }

    // MARK: - Currency Conversion

    /// Convert budget amount to user's primary currency
    private var convertedBudgetAmount: Double {
        let primaryCurrency = currencyPrefs.primaryCurrency
        let amount = periodAdjustedBudgetAmount
        if budget.currency == primaryCurrency {
            return amount
        }
        return rateManager.convertAmount(amount, from: budget.currency, to: primaryCurrency)
    }

    /// Convert spent amount to user's primary currency
    private var convertedSpentAmount: Double {
        let primaryCurrency = currencyPrefs.primaryCurrency
        if budget.currency == primaryCurrency {
            return spentAmount
        }
        return rateManager.convertAmount(spentAmount, from: budget.currency, to: primaryCurrency)
    }

    // MARK: - Computed Properties

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
            return AppColors.destructiveForeground  // Red - over budget
        }
        if percentUsed >= 0.75 {
            return Color(hex: "FF9E15") ?? AppColors.accentOrange  // Orange - 75-100%
        }
        if percentUsed >= 0.5 {
            return Color(hex: "FFCC00") ?? .yellow  // Yellow - 50-75%
        }
        return AppColors.successForeground  // Green - under 50%
    }

    // MARK: - Body

    var body: some View {
        Button(action: onMenuTap) {
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

                    // Three-dot menu indicator
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.foregroundTertiary)
                        .frame(width: 24, height: 24)
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
                    // Spent / Budget (converted to primary currency)
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
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Convenience Initializers

extension BudgetCard {
    /// Initializer that automatically calculates spent amount for the budget's original period
    init(budget: Budget, onMenuTap: @escaping () -> Void) {
        self.budget = budget
        self.spentAmount = BudgetManager.shared.spentAmount(for: budget)
        self.displayPeriod = nil
        self.onMenuTap = onMenuTap
    }

    /// Initializer that shows budget equivalent for a different display period
    init(budget: Budget, displayPeriod: BudgetPeriod, onMenuTap: @escaping () -> Void) {
        self.budget = budget
        self.displayPeriod = displayPeriod
        // Calculate spent amount for the display period, not the original budget period
        self.spentAmount = BudgetManager.shared.spentAmount(for: budget, displayPeriod: displayPeriod)
        self.onMenuTap = onMenuTap
    }

    /// Initializer that shows budget equivalent for a display period at a specific date
    init(budget: Budget, displayPeriod: BudgetPeriod, date: Date, onMenuTap: @escaping () -> Void) {
        self.budget = budget
        self.displayPeriod = displayPeriod
        // Calculate spent amount for the display period containing the specific date
        self.spentAmount = BudgetManager.shared.spentAmount(for: budget, displayPeriod: displayPeriod, on: date)
        self.onMenuTap = onMenuTap
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Over budget example
        BudgetCard(
            budget: Budget(
                walletId: UUID(),
                categoryId: UUID(),
                categoryName: "Transportation",
                amount: 5000,
                currency: .php,
                period: .monthly
            ),
            spentAmount: 5500,
            displayPeriod: .monthly,
            onMenuTap: {}
        )

        // Under budget (orange) example
        BudgetCard(
            budget: Budget(
                walletId: UUID(),
                categoryId: UUID(),
                categoryName: "Bills & Utilities",
                amount: 5000,
                currency: .php,
                period: .monthly
            ),
            spentAmount: 3500,
            displayPeriod: .monthly,
            onMenuTap: {}
        )

        // Daily view of monthly budget (period conversion)
        BudgetCard(
            budget: Budget(
                walletId: UUID(),
                categoryId: UUID(),
                categoryName: "Food",
                amount: 15000,  // 15,000/month
                currency: .php,
                period: .monthly
            ),
            spentAmount: 400,
            displayPeriod: .daily,  // Shows ~493/day equivalent
            onMenuTap: {}
        )
    }
    .padding()
    .background(AppColors.surfacePrimary)
}
