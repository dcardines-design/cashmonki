//
//  BudgetSummaryCard.swift
//  CashMonki
//
//  Created by Claude on 12/24/25.
//

import SwiftUI

struct BudgetSummaryCard: View {
    let budgets: [Budget]
    let displayPeriod: BudgetPeriod
    let date: Date

    @ObservedObject private var currencyPrefs = CurrencyPreferences.shared
    private let budgetManager = BudgetManager.shared
    private let rateManager = CurrencyRateManager.shared

    // MARK: - Category Colors (matching transactions breakdown)

    private let categoryColors: [Color] = [
        Color(hex: "DE4706") ?? AppColors.destructiveForeground,  // Top 1
        Color(hex: "FF6C29") ?? AppColors.destructiveForeground,  // Top 2
        Color(hex: "FFA100") ?? AppColors.accentOrange,           // Top 3
        Color(hex: "F7CD07") ?? AppColors.accentOrange,           // Top 4
        AppColors.linePrimary                                      // Others
    ]

    // MARK: - Budget Data

    private struct BudgetData: Identifiable {
        let id: UUID
        let categoryName: String
        let emoji: String
        let spent: Double
        let budget: Double
        let color: Color

        var spentPercentage: Double {
            guard budget > 0 else { return 0 }
            return (spent / budget) * 100
        }
    }

    // MARK: - Computed Properties

    private var budgetDataList: [BudgetData] {
        // Sort by spent amount (highest first) to assign colors by ranking
        let sortedBudgets = budgets.sorted {
            getSpentAmount(for: $0) > getSpentAmount(for: $1)
        }

        return sortedBudgets.enumerated().map { index, budget in
            let spent = getSpentAmount(for: budget)
            let budgetAmount = getBudgetAmount(for: budget)
            let colorIndex = min(index, categoryColors.count - 1)

            return BudgetData(
                id: budget.id,
                categoryName: budget.categoryName,
                emoji: TxnCategoryIcon.emojiFor(category: budget.categoryName),
                spent: spent,
                budget: budgetAmount,
                color: categoryColors[colorIndex]
            )
        }
    }

    private var totalSpent: Double {
        budgets.reduce(0) { $0 + getSpentAmount(for: $1) }
    }

    private var totalBudget: Double {
        budgets.reduce(0) { $0 + getBudgetAmount(for: $1) }
    }

    private var periodLabel: String {
        switch displayPeriod {
        case .daily:
            return "Total budget today"
        case .weekly:
            return "Total budget this week"
        case .monthly:
            return "Total budget this month"
        case .quarterly:
            return "Total budget this quarter"
        case .yearly:
            return "Total budget this year"
        }
    }

    // MARK: - Helper Methods

    private func getSpentAmount(for budget: Budget) -> Double {
        let spent = budgetManager.spentAmount(for: budget, displayPeriod: displayPeriod, on: date)
        // Convert to primary currency if needed
        if budget.currency != currencyPrefs.primaryCurrency {
            return rateManager.convertAmount(spent, from: budget.currency, to: currencyPrefs.primaryCurrency)
        }
        return spent
    }

    private func getBudgetAmount(for budget: Budget) -> Double {
        var amount = budget.amount
        // Convert period if needed
        if budget.period != displayPeriod {
            amount = budgetManager.convertAmount(amount, from: budget.period, to: displayPeriod)
        }
        // Convert currency if needed
        if budget.currency != currencyPrefs.primaryCurrency {
            return rateManager.convertAmount(amount, from: budget.currency, to: currencyPrefs.primaryCurrency)
        }
        return amount
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header + Total amounts (8px spacing to match Balance card)
                VStack(alignment: .leading, spacing: 8) {
                    Text(periodLabel)
                        .font(AppFonts.overusedGroteskMedium(size: 18))
                        .foregroundStyle(.secondary)

                    // Total amounts
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(currencyPrefs.formatPrimaryAmount(totalSpent))
                            .font(AppFonts.overusedGroteskSemiBold(size: 34))
                            .foregroundStyle(.primary)

                        HStack(spacing: 4) {
                            Text("/")
                                .font(AppFonts.overusedGroteskMedium(size: 18))
                                .foregroundStyle(AppColors.foregroundTertiary)

                            Text(currencyPrefs.formatPrimaryAmount(totalBudget))
                                .font(AppFonts.overusedGroteskMedium(size: 18))
                                .foregroundStyle(AppColors.foregroundTertiary)
                        }
                    }
                }

                // Segmented progress bar
                segmentedProgressBar
            }

            // Budget breakdown list
            VStack(spacing: 16) {
                ForEach(budgetDataList) { data in
                    budgetRow(data: data)
                }
            }
        }
        .padding(20)
        .background(AppColors.backgroundWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Segmented Progress Bar

    private var segmentedProgressBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(budgetDataList) { data in
                    let proportion = totalSpent > 0 ? data.spent / totalSpent : 0
                    let width = proportion * geometry.size.width

                    if width > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(data.color)
                            .frame(width: max(0, width - 1))
                    }
                }

                // Fill remaining space if totalSpent < totalBudget
                let usedProportion = totalBudget > 0 ? min(totalSpent / totalBudget, 1.0) : 0
                let remainingWidth = geometry.size.width * (1.0 - usedProportion)

                if remainingWidth > 2 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.linePrimary)
                        .frame(width: remainingWidth)
                }
            }
        }
        .frame(height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Budget Row

    private func budgetRow(data: BudgetData) -> some View {
        HStack(spacing: 8) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(data.color)
                .frame(width: 4, height: 24)

            // Emoji
            Text(data.emoji)
                .font(.system(size: 16))

            // Category name
            Text(data.categoryName)
                .font(AppFonts.overusedGroteskMedium(size: 16))
                .foregroundStyle(AppColors.foregroundPrimary)

            Spacer()

            // Amounts and percentage
            HStack(spacing: 4) {
                Text(currencyPrefs.formatPrimaryAmount(data.spent))
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundStyle(data.spent > data.budget ? AppColors.destructiveForeground : AppColors.foregroundSecondary)

                Text("/")
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundStyle(AppColors.foregroundTertiary)

                Text(currencyPrefs.formatPrimaryAmount(data.budget))
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundStyle(AppColors.foregroundTertiary)

                Text("·")
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundStyle(AppColors.foregroundTertiary)

                Text("\(Int(data.spentPercentage))%")
                    .font(AppFonts.overusedGroteskMedium(size: 14))
                    .foregroundStyle(AppColors.foregroundTertiary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        BudgetSummaryCard(
            budgets: [
                Budget(walletId: UUID(), categoryId: UUID(), categoryName: "Transportation", amount: 5500, currency: .php, period: .monthly),
                Budget(walletId: UUID(), categoryId: UUID(), categoryName: "Bills & Utilities", amount: 5000, currency: .php, period: .monthly),
                Budget(walletId: UUID(), categoryId: UUID(), categoryName: "Entertainment", amount: 1200, currency: .php, period: .monthly),
                Budget(walletId: UUID(), categoryId: UUID(), categoryName: "Dining & Drinks", amount: 1200, currency: .php, period: .monthly)
            ],
            displayPeriod: .daily,
            date: Date()
        )
    }
    .padding()
    .background(AppColors.surfacePrimary)
}
